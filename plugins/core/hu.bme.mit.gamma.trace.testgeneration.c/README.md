## Prerequisites

To run the generated C code and tests, you'll need the following software installed:

**1. Eclipse CDT:**

Eclipse CDT is a modular, open-source plugin extending the Eclipse platform with tools for developing, debugging, and analyzing C and C++ applications. You can either install Eclipse CDT as a [separate bundle](https://projects.eclipse.org/projects/tools.cdt) or through the [Eclipse Marketplace](https://marketplace.eclipse.org/content/complete-eclipse-cc-ide) within your existing DSL environment.

**2. gcc Compiler:**

To install the latest version of Cygwin on Windows, navigate to the [official Cygwin website](https://www.cygwin.com/install.html) and follow these steps:

Upon launching the `Cygwin Setup - Select Packages` window, access the `View` dropdown menu and opt for `Full`. Proceed by selecting the necessary packages: `automake`, `cgdb`, `cmake`, `cmake-debuginfo`, `gcc-core`, `gcc-g++`, `gdb`, `gdb-debuginfo`, `make`.
Allow the setup process to download and install the chosen packages, being mindful that this operation might consume some time. Add Cygwin to the Windows PATH environment variable. Within the "System variables" section, locate "Path", click "Edit", and append the path to your Cygwin bin directory (e.g., `C:\cygwin\bin`).

For Linux distributions, GCC is typically pre-installed and readily available.

**3. Unity Unit Testing Framework:**

 The source code and documentation for the Unity Framework are hosted on GitHub at [this repository](https://github.com/ThrowTheSwitch/Unity). Detailed instructions for installation can be accessed through the official tutorial provided [here](https://www.throwtheswitch.org/build/make). Other build options are available. Following these guidelines and adding Unity's build folder into an environment variable named `unity` will enable the use of the framework within Gamma.

**Note:** Ensure your system path includes the necessary executables (e.g., `gcc`, `unity`) after installation.

## Usage

To run the generated C code and tests together you'll need the following steps:

**1. C Project:**

In Eclipse CDT, create a new C project by navigating to `File > New > Project > C/C++ > C Project`. Select `Executable > Empty project` from `Project type`, configuring details, and clicking Finish.

**2. Running:**

Copy the generated C code, tests and makefile from the Gamma project's `src-gen` and `test-gen` folder. At this point, you should be capable of building the project using the built-in hammer button within the Eclipse CDT environment. Upon execution, the generated makefile will initiate the testing process.

**Note:** Ensure your system path includes the necessary executables (e.g., `gcc`, `unity`) after installation.