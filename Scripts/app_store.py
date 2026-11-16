"""What the App Store release reads from the repository, and the checks of it that need more than an
assertion: the listing under AppStore/metadata (one file per App Store Connect field, fastlane
deliver's layout), the age rating, and the settings in project.yml. Scripts/app_store_test.py runs
them on the repository and on fixtures.
"""

import pathlib
import re

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
# What separates the words of a name: "Stix: Claim the Field" is stix, claim, the and field.
NAME_WORD_SEPARATOR = r"[^\w]+"
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
# The age rating questions App Store Connect answers with yes or no; every other one takes a level.
BOOLEAN_AGE_QUESTIONS = {
    "advertising", "ageAssurance", "gambling", "healthOrWellnessTopics", "lootBox",
    "messagingAndChat", "parentalControls", "socialMedia", "unrestrictedWebAccess",
    "userGeneratedContent",
}
NO_LEVEL = "NONE"


def project_settings(name, text):
    """The values of `name: value` in a project.yml's text, unquoted."""
    return re.findall(rf'^ *{name}: *"?([^"\n]*)"?$', text, re.MULTILINE)


def project_setting(name, text=None):
    """The value of `name: value` in project.yml, unquoted; the file sets each name once."""
    values = project_settings(name, PROJECT.read_text() if text is None else text)
    if len(values) != 1:
        raise AssertionError(f"{name} is set {len(values)} times in project.yml")
    return values[0]


def quoted_project_setting(name, text):
    """The value of `name: "value"` in a project.yml's text, or None unless the name is set exactly
    once, quoted: the form the release workflow's version check reads."""
    values = re.findall(rf'^ *{name}: "([^"\n]*)"$', text, re.MULTILINE)
    return values[0] if len(values) == 1 else None


def locales(metadata=METADATA):
    return sorted(path.name for path in metadata.iterdir() if path.is_dir())


def field(name, locale=None, metadata=METADATA):
    directory = metadata / locale if locale else metadata
    return (directory / (name + TEXT_EXTENSION)).read_text(encoding="utf-8").strip("\n")


def field_names(directory):
    return sorted(path.stem for path in directory.glob("*" + TEXT_EXTENSION))


def language_code(locale):
    return locale.split(REGION_SEPARATOR)[0]


def name_words(name):
    return {word for word in re.split(NAME_WORD_SEPARATOR, name.lower()) if word}


def keyword_problems(keywords, name):
    """What wastes a listing's 100 characters of keywords: an empty one, one repeated (the store
    ignores case), one padded with spaces, or the name or one of its words, which the store already
    matches."""
    problems = []
    seen = set()
    repeated = {name.lower()} | name_words(name)
    for keyword in keywords.split(KEYWORD_SEPARATOR):
        if not keyword:
            problems.append("an empty keyword")
            continue
        if keyword != keyword.strip():
            problems.append(f"'{keyword}' is padded")
        folded = keyword.strip().lower()
        if folded in seen:
            problems.append(f"'{keyword}' is repeated")
        if folded in repeated:
            problems.append(f"'{keyword}' repeats the name")
        seen.add(folded)
    return problems


def release_notes_problems(metadata=METADATA):
    """Release notes in some locales only, or empty, or over App Store Connect's limit."""
    all_locales = locales(metadata)
    present = [locale for locale in all_locales if RELEASE_NOTES in field_names(metadata / locale)]
    problems = []
    if present and present != all_locales:
        problems.append(f"release notes in {present} but not in {sorted(set(all_locales) - set(present))}")
    for locale in present:
        notes = field(RELEASE_NOTES, locale, metadata)
        if not notes:
            problems.append(f"{locale}: empty release notes")
        elif len(notes) > RELEASE_NOTES_LIMIT:
            problems.append(f"{locale}: release notes of {len(notes)} characters")
    return problems


def uses_trademark(text):
    return TRADEMARK in text.lower()


def age_rating_problems(answers):
    """The answers that are not No (the boolean questions, exactly `false`) or None (the others,
    exactly "NONE"): a 4+ rating."""
    problems = []
    for question, answer in answers.items():
        if question in BOOLEAN_AGE_QUESTIONS:
            if answer is not False:
                problems.append(f"{question}: {answer!r}, not false")
        elif answer != NO_LEVEL:
            problems.append(f"{question}: {answer!r}, not {NO_LEVEL!r}")
    return problems
