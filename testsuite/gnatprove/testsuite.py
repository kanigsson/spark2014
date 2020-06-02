#! /usr/bin/env python3

from e3.testsuite import Testsuite
from e3.testsuite.testcase_finder import AdaCoreLegacyTestFinder
from e3.testsuite.driver.adacore import AdaCoreLegacyTestDriver
import os

testsuite_root = os.getcwd()

class SPARKTestsuite(Testsuite):
    """Testsuite for SPARK."""
    @property
    def test_finders(self):
        return [AdaCoreLegacyTestFinder(AdaCoreLegacyTestDriver)]

    # Add a command-line flag to the testsuite script to allow users to
    # trigger baseline rewriting.
    def add_options(self, parser):
        parser.add_argument(
            "--rewrite", action="store_true",
            help="Rewrite test baselines according to current outputs"
        )

    def compute_environ(self):
        python_lib = os.path.join(testsuite_root,"lib","python")
        pypath = "PYTHONPATH"
        if pypath in os.environ:
            os.environ["PYTHONPATH"] += ":" + python_lib
        else:
            os.environ["PYTHONPATH"] = python_lib
        return os.environ

    def set_up(self):
        super(SPARKTestsuite, self).set_up()
        self.env.discs = self.env.discriminants
        self.env.test_environ = self.compute_environ()
        self.env.rewrite_baselines = self.main.args.rewrite


if __name__ == "__main__":
    SPARKTestsuite().testsuite_main()
