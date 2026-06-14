"""Tests for the optional desktop ``visible_profiles`` allowlist.

The desktop UI may pin ``~/.hermes/desktop.json`` with a ``visible_profiles``
list. The allowlist is a presentation-layer concern: it only takes effect when
a caller opts in via ``list_profiles(visible_only=True)``. The default
``list_profiles()`` always returns every profile, so assignee resolution,
gateway enumeration, and other internal callers never see a truncated set.
When the file is absent, empty, or malformed, the allowlist is ignored and
every profile is returned (fail-open).
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from hermes_cli import profiles


@pytest.fixture
def hermes_home(monkeypatch, tmp_path):
    """Point the platform-default Hermes home at a fresh tmp dir."""
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    monkeypatch.delenv("HERMES_HOME", raising=False)
    home = tmp_path / ".hermes"
    home.mkdir()
    return home


# ---------------------------------------------------------------------------
# _desktop_visible_profile_names
# ---------------------------------------------------------------------------

def test_visible_names_none_when_file_absent(hermes_home):
    assert profiles._desktop_visible_profile_names() is None


def test_visible_names_parses_list_and_strips(hermes_home):
    (hermes_home / "desktop.json").write_text(
        json.dumps({"visible_profiles": [" work ", "coder", ""]})
    )
    assert profiles._desktop_visible_profile_names() == {"work", "coder"}


def test_visible_names_none_when_empty_list(hermes_home):
    (hermes_home / "desktop.json").write_text(json.dumps({"visible_profiles": []}))
    assert profiles._desktop_visible_profile_names() is None


def test_visible_names_none_when_not_a_list(hermes_home):
    (hermes_home / "desktop.json").write_text(json.dumps({"visible_profiles": "work"}))
    assert profiles._desktop_visible_profile_names() is None


def test_visible_names_none_when_top_level_not_a_dict(hermes_home):
    # A bare list (or any non-object) must not raise AttributeError on .get.
    (hermes_home / "desktop.json").write_text(json.dumps(["work"]))
    assert profiles._desktop_visible_profile_names() is None


def test_visible_names_none_when_malformed_json(hermes_home):
    (hermes_home / "desktop.json").write_text("{not json")
    assert profiles._desktop_visible_profile_names() is None


def test_visible_names_none_when_only_blank_entries(hermes_home):
    (hermes_home / "desktop.json").write_text(
        json.dumps({"visible_profiles": ["  ", ""]})
    )
    assert profiles._desktop_visible_profile_names() is None


# ---------------------------------------------------------------------------
# list_profiles() integration
# ---------------------------------------------------------------------------

def _make_profiles(home: Path) -> None:
    """Create a default home plus two named profiles ('work', 'coder')."""
    profiles_root = home / "profiles"
    for name in ("work", "coder"):
        (profiles_root / name).mkdir(parents=True)


def test_list_profiles_unfiltered_without_desktop_json(hermes_home):
    _make_profiles(hermes_home)
    names = {p.name for p in profiles.list_profiles()}
    assert names == {"default", "work", "coder"}


def test_list_profiles_default_ignores_allowlist(hermes_home):
    # The allowlist must never truncate the default (internal) call path —
    # assignee resolution and gateway enumeration depend on the full set.
    _make_profiles(hermes_home)
    (hermes_home / "desktop.json").write_text(
        json.dumps({"visible_profiles": ["work"]})
    )
    names = {p.name for p in profiles.list_profiles()}
    assert names == {"default", "work", "coder"}


def test_list_profiles_visible_only_filtered_by_allowlist(hermes_home):
    _make_profiles(hermes_home)
    (hermes_home / "desktop.json").write_text(
        json.dumps({"visible_profiles": ["default", "work"]})
    )
    names = {p.name for p in profiles.list_profiles(visible_only=True)}
    assert names == {"default", "work"}


def test_list_profiles_visible_only_unfiltered_without_desktop_json(hermes_home):
    # visible_only is fail-open: no allowlist file => every profile is returned.
    _make_profiles(hermes_home)
    names = {p.name for p in profiles.list_profiles(visible_only=True)}
    assert names == {"default", "work", "coder"}


def test_list_profiles_visible_only_unknown_name_is_intersection(hermes_home):
    _make_profiles(hermes_home)
    (hermes_home / "desktop.json").write_text(
        json.dumps({"visible_profiles": ["work", "ghost"]})
    )
    names = {p.name for p in profiles.list_profiles(visible_only=True)}
    assert names == {"work"}
