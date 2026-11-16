#!/usr/bin/env python3
"""Checks of what the App Store release reads from the repository (app_store.py): the listing under
AppStore/metadata, the privacy policy it links to, the age rating, the export options, and the
version and bundle identifier in project.yml; then the checks themselves, on fixtures. They read
files only, so they run on Linux with the other script tests.

    python3 Scripts/app_store_test.py
"""

import json
import pathlib
import plistlib
import re
import tempfile
import unittest
from urllib.parse import urlparse

from app_store import (
    APP_SOURCES, GAMES_CATEGORY, GAMES_SUBCATEGORY_PREFIX, LIMITS, LOCALISATION_PATTERNS, METADATA,
    PRIMARY_LOCALE, PRIVACY_POLICIES, PROJECT, RELEASE_NOTES, RELEASE_NOTES_LIMIT, REPOSITORY_FILE_PREFIX, ROOT,
    SEARCHED_FIELDS, SHARED_FIELDS, STORE, STORE_LOCALES, TEXT_EXTENSION, URL_FIELDS, VERSION_PATTERN,
    BUILD_PATTERN, age_rating_problems, field, field_names, keyword_problems, language_code, locales,
    project_setting, quoted_project_setting, release_notes_problems, uses_trademark,
)

STORE_NAME = "Stix: Claim the Field"
FIXTURE_LOCALES = ["en-US", "fr-FR"]
FIXTURE_NOTES = "Faster Sparx."


class ListingTests(unittest.TestCase):
    def test_the_locales_are_app_store_locales_with_the_primary_one(self):
        self.assertIn(PRIMARY_LOCALE, locales())
        self.assertEqual(set(locales()) - STORE_LOCALES, set())

    def test_the_store_and_the_app_have_the_same_languages(self):
        # The app is not localised: its only language is the development language. A localisation
        # fails the first check, as a reminder that the listing needs that language too.
        for pattern in LOCALISATION_PATTERNS:
            self.assertEqual(list(APP_SOURCES.rglob(pattern)), [], pattern)
        app = {project_setting("developmentLanguage")}
        self.assertEqual({language_code(locale) for locale in locales()}, app)

    def test_every_locale_has_every_field_within_its_limit(self):
        for locale in locales():
            for name, limit in LIMITS.items():
                with self.subTest(locale=locale, field=name):
                    text = field(name, locale)
                    self.assertTrue(text)
                    self.assertLessEqual(len(text), limit)

    def test_there_are_no_other_fields(self):
        self.assertEqual(field_names(METADATA), sorted(SHARED_FIELDS))
        expected = sorted(list(LIMITS) + URL_FIELDS)
        for locale in locales():
            names = field_names(METADATA / locale)
            self.assertEqual([name for name in names if name != RELEASE_NOTES], expected, locale)

    def test_release_notes_are_in_every_locale_or_none(self):
        self.assertEqual(release_notes_problems(), [])

    def test_the_shared_fields_are_a_game_with_a_copyright(self):
        self.assertTrue(field("copyright"))
        self.assertEqual(field("primary_category"), GAMES_CATEGORY)
        self.assertTrue(field("primary_first_sub_category").startswith(GAMES_SUBCATEGORY_PREFIX))

    def test_the_urls_are_secure_and_the_privacy_policy_is_in_the_repository(self):
        for locale in locales():
            for name in URL_FIELDS:
                self.assertEqual(urlparse(field(name, locale)).scheme, "https", f"{locale} {name}")
            policy = field("privacy_url", locale)
            self.assertTrue(policy.startswith(REPOSITORY_FILE_PREFIX), locale)
            path = ROOT / policy[len(REPOSITORY_FILE_PREFIX):]
            self.assertTrue(path.is_file(), f"{locale}: {path} is not in the repository")

    def test_each_locale_links_to_the_privacy_policy_in_its_language(self):
        self.assertEqual(set(PRIVACY_POLICIES), set(locales()))
        for locale, policy in PRIVACY_POLICIES.items():
            self.assertEqual(field("privacy_url", locale), REPOSITORY_FILE_PREFIX + policy, locale)

    def test_each_privacy_policy_names_the_app_as_its_listing_does(self):
        for locale, policy in PRIVACY_POLICIES.items():
            text = (ROOT / policy).read_text(encoding="utf-8")
            self.assertIn(field("name", locale), text, locale)

    def test_the_keywords_waste_no_characters(self):
        for locale in locales():
            self.assertEqual(keyword_problems(field("keywords", locale), field("name", locale)), [], locale)

    def test_the_listing_does_not_use_the_trademark(self):
        for locale in locales():
            for name in SEARCHED_FIELDS:
                self.assertFalse(uses_trademark(field(name, locale)), f"{locale} {name}")


class ReleaseTests(unittest.TestCase):
    def test_the_version_is_three_numbers_quoted(self):
        # Quoted, as the release workflow's check of the tag reads it.
        version = quoted_project_setting("MARKETING_VERSION", PROJECT.read_text())
        self.assertIsNotNone(version)
        self.assertRegex(version, VERSION_PATTERN)

    def test_the_local_build_number_is_a_whole_number(self):
        self.assertRegex(project_setting("CURRENT_PROJECT_VERSION"), BUILD_PATTERN)

    def test_the_listing_is_for_the_app_the_project_builds(self):
        deliverfile = (STORE / "Deliverfile").read_text()
        identifiers = re.findall(r'^app_identifier "([^"]+)"$', deliverfile, re.MULTILINE)
        self.assertEqual(identifiers, [project_setting("PRODUCT_BUNDLE_IDENTIFIER")])

    def test_every_age_rating_answer_is_none_or_no(self):
        # 4+: abstract enemies, no violence, no gambling, nothing shared between players.
        answers = json.loads((STORE / "age_rating.json").read_text())
        self.assertTrue(answers)
        self.assertEqual(age_rating_problems(answers), [])

    def test_the_export_uploads_for_the_app_store_without_a_team(self):
        with (STORE / "ExportOptions.plist").open("rb") as file:
            options = plistlib.load(file)
        self.assertEqual(options["method"], "app-store-connect")
        self.assertEqual(options["destination"], "upload")
        self.assertFalse(options["manageAppVersionAndBuildNumber"])
        # The release workflow inserts the team, and plutil -insert fails on a key already there.
        self.assertNotIn("teamID", options)


class KeywordCheckTests(unittest.TestCase):
    def test_distinct_unpadded_keywords_pass(self):
        self.assertEqual(keyword_problems("arcade,no ads,1981", STORE_NAME), [])

    def test_an_empty_keyword_fails(self):
        self.assertEqual(keyword_problems("arcade,,retro", STORE_NAME), ["an empty keyword"])
        self.assertEqual(keyword_problems("arcade,retro,", STORE_NAME), ["an empty keyword"])

    def test_a_keyword_repeated_in_another_case_fails(self):
        self.assertEqual(keyword_problems("Lines,lines", STORE_NAME), ["'lines' is repeated"])

    def test_a_padded_keyword_fails(self):
        self.assertEqual(keyword_problems("arcade, retro", STORE_NAME), ["' retro' is padded"])

    def test_the_name_or_a_word_of_it_fails(self):
        self.assertEqual(
            keyword_problems("stix: claim the field", STORE_NAME), ["'stix: claim the field' repeats the name"]
        )
        self.assertEqual(keyword_problems("arcade,Stix", STORE_NAME), ["'Stix' repeats the name"])
        self.assertEqual(keyword_problems("field", STORE_NAME), ["'field' repeats the name"])


class TrademarkCheckTests(unittest.TestCase):
    def test_the_trademark_is_found_in_any_case(self):
        self.assertTrue(uses_trademark("QIX Arcade"))
        self.assertTrue(uses_trademark("Qix"))
        self.assertTrue(uses_trademark("a qix clone"))

    def test_the_store_name_does_not_use_it(self):
        self.assertFalse(uses_trademark(STORE_NAME))


class ReleaseNotesCheckTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.metadata = pathlib.Path(self.directory.name)
        for locale in FIXTURE_LOCALES:
            (self.metadata / locale).mkdir()

    def tearDown(self):
        self.directory.cleanup()

    def notes(self, locale, text):
        (self.metadata / locale / (RELEASE_NOTES + TEXT_EXTENSION)).write_text(text, encoding="utf-8")

    def test_no_notes_pass(self):
        self.assertEqual(release_notes_problems(self.metadata), [])

    def test_notes_in_every_locale_at_the_limit_pass(self):
        self.notes("en-US", FIXTURE_NOTES)
        self.notes("fr-FR", "x" * RELEASE_NOTES_LIMIT)
        self.assertEqual(release_notes_problems(self.metadata), [])

    def test_notes_in_one_locale_only_fail(self):
        self.notes("en-US", FIXTURE_NOTES)
        self.assertEqual(
            release_notes_problems(self.metadata), ["release notes in ['en-US'] but not in ['fr-FR']"]
        )

    def test_empty_notes_fail(self):
        self.notes("en-US", FIXTURE_NOTES)
        self.notes("fr-FR", "\n")
        self.assertEqual(release_notes_problems(self.metadata), ["fr-FR: empty release notes"])

    def test_notes_over_the_limit_fail(self):
        self.notes("en-US", FIXTURE_NOTES)
        over = RELEASE_NOTES_LIMIT + 1
        self.notes("fr-FR", "x" * over)
        self.assertEqual(release_notes_problems(self.metadata), [f"fr-FR: release notes of {over} characters"])


class AgeRatingCheckTests(unittest.TestCase):
    def test_no_and_none_pass(self):
        self.assertEqual(age_rating_problems({"gambling": False, "contests": "NONE"}), [])

    def test_zero_is_not_no(self):
        self.assertEqual(age_rating_problems({"gambling": 0}), ["gambling: 0, not false"])

    def test_none_is_not_an_answer_to_a_yes_or_no_question(self):
        self.assertEqual(age_rating_problems({"lootBox": "NONE"}), ["lootBox: 'NONE', not false"])

    def test_false_is_not_a_level(self):
        self.assertEqual(age_rating_problems({"contests": False}), ["contests: False, not 'NONE'"])

    def test_a_level_above_none_fails(self):
        self.assertEqual(
            age_rating_problems({"violenceCartoonOrFantasy": "INFREQUENT_OR_MILD"}),
            ["violenceCartoonOrFantasy: 'INFREQUENT_OR_MILD', not 'NONE'"],
        )


class ProjectSettingTests(unittest.TestCase):
    def test_a_quoted_version_is_read(self):
        self.assertEqual(quoted_project_setting("MARKETING_VERSION", '    MARKETING_VERSION: "1.0.0"\n'), "1.0.0")

    def test_an_unquoted_version_is_not(self):
        # project_setting accepts it, but the release workflow's check of the tag would read nothing.
        text = "    MARKETING_VERSION: 1.0.0\n"
        self.assertEqual(project_setting("MARKETING_VERSION", text), "1.0.0")
        self.assertIsNone(quoted_project_setting("MARKETING_VERSION", text))

    def test_a_setting_set_twice_is_refused(self):
        text = '    MARKETING_VERSION: "1.0.0"\n    MARKETING_VERSION: "1.0.1"\n'
        self.assertIsNone(quoted_project_setting("MARKETING_VERSION", text))
        with self.assertRaisesRegex(AssertionError, "MARKETING_VERSION is set 2 times in project.yml"):
            project_setting("MARKETING_VERSION", text)


if __name__ == "__main__":
    unittest.main()
