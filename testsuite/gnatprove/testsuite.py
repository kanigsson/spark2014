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
        # This will create a testcase for all directories whose name matches a
        # TN, using the MyDriver test driver.
        return [AdaCoreLegacyTestFinder(AdaCoreLegacyTestDriver)]

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


if __name__ == "__main__":
    SPARKTestsuite().testsuite_main()
