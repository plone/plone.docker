#!/usr/bin/env python3

import importlib
import os
import tempfile
from pathlib import Path
import sys
import unittest

script_file_name = 'docker-initialize.py'
class_name = 'Environment'
input_file_names = dict(
    zope_conf="zope.conf",
    zeopack_conf="zeopack",
    zeoserver_conf="zeo.conf"
)
output_file_names = dict(
    custom_conf="custom.cfg",
    cors_conf="999-additional-overrides.zcml",
    zeopack_conf=input_file_names['zeopack_conf'],
    zeoserver_conf=input_file_names['zeoserver_conf']
)

test_path = Path(__file__).parent
expected_files_path = test_path.joinpath("expected-files")
root_path = test_path.parent
script_files = list(root_path.glob('**/' + script_file_name))

if not expected_files_path.exists():
    expected_files_path.mkdir()


def _import_class(file):
    module_path = file.parent
    sys.path.insert(0, str(module_path))
    try:
        module = importlib.import_module(file.stem)
        return getattr(module, class_name)
    finally:
        sys.path.remove(str(module_path))


def _read_file(path: Path):
    if path.exists():
        return path.read_text()
    else:
        return None


def all_scripts(func):
    def wrapper(self):
        for file in script_files:
            def setup(env):
                environment_class = _import_class(file)
                filename_parameters = dict(input_file_names)
                filename_parameters.update(output_file_names)
                instance = environment_class(
                    env=env,
                    **filename_parameters
                )
                instance.setup()

            relative_path = file.parent.relative_to(root_path)
            with self.subTest(relative_path):
                func(self, setup)

    return wrapper


def sandbox_directory(func):
    def wrapper(self):
        old_directory = os.getcwd()
        with tempfile.TemporaryDirectory() as output_directory:
            os.chdir(output_directory)
            try:
                func(self)
            finally:
                os.chdir(old_directory)

    return wrapper


class EnvironmentTest(unittest.TestCase):
    @sandbox_directory
    @all_scripts
    def test_empty_env(self, setup):
        setup({})
        for file in output_file_names.values():
            self.assertFalse(Path(file).exists(), "{0} must not exist!".format(file))

    @sandbox_directory
    @all_scripts
    def test_full_env(self, setup):
        for input_file in input_file_names.values():
            Path(input_file).write_text('dummy content;')
        setup(dict(
            FIND_LINKS='not well hidden',
            ADDONS='very nice addons',
            ZCML='random value',
            DEVELOP='this has content',
            SITE='dummy',
            PROFILES='how profily',
            VERSIONS='old and new',
            FILE_LOGGING='bigtrees',
            SOURCES='repo,sitory',
            BUILDOUT_EXTENDS='more extensions',
            ZEO_ADDRESS='home street 1234',
            ZEO_SHARED_BLOB_DIR='yes',
            RELSTORAGE_NAME='uncle',
            CORS_ALLOW_ORIGIN='anything'
        ))
        for file in output_file_names.values():
            actual_content = _read_file(Path(file))
            expected_file = expected_files_path.joinpath(file)
            expected_content = _read_file(expected_file)
            if expected_content:
                self.assertEqual(expected_content, actual_content, "content of {0} does not match!".format(file))
            elif actual_content:
                expected_file.write_text(actual_content)
                self.fail("{0} does not exist, it will be generated".format(expected_file))


if __name__ == '__main__':
    unittest.main()
