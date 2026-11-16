#!/usr/bin/env python3
"""Checks of what the App Store release reads from the repository: the listing under
AppStore/metadata (one file per App Store Connect field, fastlane deliver's layout), the privacy
policy it links to, the age rating, the export options, and the version and bundle identifier in
project.yml. They read files only, so they run on Linux with the other script tests.

    python3 Scripts/app_store_test.py
"""

import json
import pathlib
import plistlib
import re
import unittest
from urllib.parse import urlparse

ROOT = pathlib.Path(__file__).resolve().parent.parent
STORE = ROOT / "AppStore"
METADATA = STORE / "metadata"
PROJECT = ROOT / "project.yml"
TEXT_EXTENSION = ".txt"

# The listing every other locale falls back to; App Store Connect calls it the primary language.
PRIMARY_LOCALE = "en-US"
# The locale codes App Store Connect accepts (fastlane deliver's names), so a folder named `en_US`
# or `en` fails here instead of at upload.
STORE_LOCALES = {
    "ar-SA", "ca", "cs", "da", "de-DE", "el", "en-AU", "en-CA", "en-GB", "en-US", "es-ES", "es-MX",
    "fi", "fr-CA", "fr-FR", "he", "hi", "hr", "hu", "id", "it", "ja", "ko", "ms", "nl-NL", "no", "pl",
    "pt-BR", "pt-PT", "ro", "ru", "sk", "sv", "th", "tr", "uk", "vi", "zh-Hans", "zh-Hant",
}
REGION_SEPARATOR = "-"
# App Store Connect's limits, in characters.
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "promotional_text": 170,
    "keywords": 100,
    "description": 4_000,
}
# The first version takes no release notes; every later one has them in every locale.
RELEASE_NOTES = "release_notes"
RELEASE_NOTES_LIMIT = 4_000
URL_FIELDS = ["privacy_url", "support_url"]
SHARED_FIELDS = ["copyright", "primary_category", "primary_first_sub_category"]
GAMES_CATEGORY = "GAMES"
GAMES_SUBCATEGORY_PREFIX = "GAMES_"
# Where `privacy_url` points: a file in this repository, as GitHub shows it on main.
REPOSITORY_FILE_PREFIX = "https://github.com/sperano/qix-swift/blob/main/"
# The privacy policy each listing links to, in its own language.
PRIVACY_POLICIES = {"en-US": "PRIVACY.md"}
KEYWORD_SEPARATOR = ","
# Taito's trademark, which the listing must not use (App Review Guidelines 2.3.7 and 5.2.1).
TRADEMARK = "qix"
# The fields a store search reads or a listing shows.
SEARCHED_FIELDS = ["name", "subtitle", "keywords", "promotional_text", "description"]
# What a localisation of the app would add: a String Catalog or a language's folder.
LOCALISATION_PATTERNS = ["*.xcstrings", "*.lproj"]
APP_SOURCES = ROOT / "Qix"
# Three dot-separated numbers, as App Store Connect wants and the release tag repeats.
VERSION_PATTERN = r"^[0-9]+\.[0-9]+\.[0-9]+$"
BUILD_PATTERN = r"^[0-9]+$"


def project_setting(name):
    """The value of `name: value` in project.yml, unquoted; the file sets each name once."""
    values = re.findall(rf'^ *{name}: *"?([^"\n]*)"?$', PROJECT.read_text(), re.MULTILINE)
    if len(values) != 1:
        raise AssertionError(f"{name} is set {len(values)} times in project.yml")
    return values[0]


def locales():
    return sorted(path.name for path in METADATA.iterdir() if path.is_dir())


def field(name, locale=None):
    directory = METADATA / locale if locale else METADATA
    return (directory / (name + TEXT_EXTENSION)).read_text(encoding="utf-8").strip("\n")


def field_names(directory):
    return sorted(path.stem for path in directory.glob("*" + TEXT_EXTENSION))


def language_code(locale):
    return locale.split(REGION_SEPARATOR)[0]


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
        present = [locale for locale in locales() if RELEASE_NOTES in field_names(METADATA / locale)]
        self.assertIn(present, ([], locales()))
        for locale in present:
            notes = field(RELEASE_NOTES, locale)
            self.assertTrue(notes, locale)
            self.assertLessEqual(len(notes), RELEASE_NOTES_LIMIT, locale)

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

    def test_keywords_are_distinct_and_unpadded(self):
        for locale in locales():
            keywords = field("keywords", locale).split(KEYWORD_SEPARATOR)
            self.assertEqual(len(set(keywords)), len(keywords), locale)
            # The space after a comma counts against the limit and adds nothing.
            self.assertEqual([keyword.strip() for keyword in keywords], keywords, locale)

    def test_the_name_is_not_a_keyword(self):
        # The store already matches the name; a keyword repeating it wastes the 100 characters.
        for locale in locales():
            keywords = [keyword.lower() for keyword in field("keywords", locale).split(KEYWORD_SEPARATOR)]
            self.assertNotIn(field("name", locale).lower(), keywords, locale)

    def test_the_listing_does_not_use_the_trademark(self):
        for locale in locales():
            for name in SEARCHED_FIELDS:
                self.assertNotIn(TRADEMARK, field(name, locale).lower(), f"{locale} {name}")


class ReleaseTests(unittest.TestCase):
    def test_the_version_is_three_numbers(self):
        self.assertRegex(project_setting("MARKETING_VERSION"), VERSION_PATTERN)

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
        for question, answer in answers.items():
            self.assertIn(answer, ("NONE", False), question)

    def test_the_export_uploads_for_the_app_store_without_a_team(self):
        with (STORE / "ExportOptions.plist").open("rb") as file:
            options = plistlib.load(file)
        self.assertEqual(options["method"], "app-store-connect")
        self.assertEqual(options["destination"], "upload")
        self.assertFalse(options["manageAppVersionAndBuildNumber"])
        # The release workflow inserts the team, and plutil -insert fails on a key already there.
        self.assertNotIn("teamID", options)


if __name__ == "__main__":
    unittest.main()
