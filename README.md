
# xctool

__xctool__ is a replacement for Apple's __xcodebuild__ that makes it
easier to build and test iOS and Mac projects.  It's especially helpful
for continuous integration setups.

It's meant to be a drop-in replacement for __xcodebuild__ that adds a
few extra features:


* **Runs the same tests as Cmd-U _(Product -> Test)_ in Xcode.**

  Ideally, _xcodebuild_ with `TEST_AFTER_BUILD=YES` would build and run
the same tests as Xcode but it doesn't.  _xctool_ looks at your scheme,
understands which targets are tests, which tests are enabled, and is
able to reproduce the same test run that _Product -> Test_ does in
Xcode.
	
  _xctool_ also knows how to run application tests that require the iOS
simulator.

  If you use [application
tests](http://developer.apple.com/library/mac/#documentation/developertools/Conceptual/UnitTesting/08-Glossary/glossary.html#//apple_ref/doc/uid/TP40002143-CH8-SW1),
you've probably seen xcodebuild skipping them with this message:
	
	```
	Skipping tests; the iPhoneSimulator platform does not currently support
	application-hosted tests (TEST_HOST set).
	```

  *xctool* understands how to startup the iOS simulator and run your
tests just as Xcode would.
	
* **Structured output of build and test results.**

  _xctool_ captures the build and test results in structured form and
you can write _Reporters_ (see
[Reporter.h](https://github.com/facebook/xctool/blob/master/xctool/xctool/Reporter.h))
that format these results however you need.  _xctool_ comes with
reporters that output plain text (`-reporter plain`), pretty
ANSI-colored text (`-reporter pretty`), and
[Phabricator](http://phabricator.org/)-formatted JSON (`-reporter
phabricator`).  There's also the raw JSON event stream (`-reporter raw`)
which looks like
[this](https://gist.github.com/fpotter/e8a0de3d3c81eaf58d20) when
pretty-printed.

* **Human-friendly, ANSI-colored output.**

  _xcodebuild_ is incredibly verbose, printing the full compile command
and output for every source file.  _xctool_ is only verbose if something
goes wrong, making it much easier to identify where the problems are.

	![pretty output](https://fpotter_public.s3.amazonaws.com/xctool-uicatalog.gif)


## Usage

xctool's commands and options are mostly a superset of xcodebuild's.  In
most cases, you can just swap __xcodebuild__ with __xctool__ and things will
run as expected but with more attractive output.

You always get help and a full list of options with:

```
path/to/xctool.sh -help
```

### Building

Building products with _xctool_ is the same as building them with
_xcodebuild_.

If you use workspaces and schemes:

```
path/to/xctool.sh \
  -workspace YourWorkspace.xcworkspace \
  -scheme YourScheme \
  build
```

If you use projects and schemes:

```
path/to/xctool.sh \
  -project YourProject.xcodeproj \
  -scheme YourScheme \
  build
```

All of the common options like `-configuration`, `-sdk`, `-arch` work
just as they do with _xcodebuild_.

NOTE: _xctool_ doesn't support directly building targets using
`-target`; you must use schemes.

### Testing

_xctool_ has a __test__ action which knows how to build and run the
tests in your scheme.  You can optionally limit what tests are run
or change the SDK they're run against.

To build and run all tests in your scheme, you would use:

```
path/to/xctool.sh \
  -workspace YourWorkspace.xcworkspace \
  -scheme YourScheme \
  test
```

To build and run just the tests in a specific target, use the `-only` option:

```
path/to/xctool.sh \
  -workspace YourWorkspace.xcworkspace \
  -scheme YourScheme \
  test -only SomeTestTarget
```

You can go further and just run a specific test class:

```
path/to/xctool.sh \
  -workspace YourWorkspace.xcworkspace \
  -scheme YourScheme \
  test -only SomeTestTarget:SomeTestClass
```

Or, even further and run just a single test method:

```
path/to/xctool.sh \
  -workspace YourWorkspace.xcworkspace \
  -scheme YourScheme \
  test -only SomeTestTarget:SomeTestClass/testSomeMethod
```

You can also run tests against a different SDK:

```
path/to/xctool.sh \
  -workspace YourWorkspace.xcworkspace \
  -scheme YourScheme \
  test -test-sdk iphonesimulator5.1
```

#### Building Tests

While __test__ will build and run your tests, sometimes you want to
build them without running them.  For that, use __build-tests__.

For example:

```
path/to/xctool.sh \
  -workspace YourWorkspace.xcworkspace \
  -scheme YourScheme \
  build-tests
```

You can optionally just build a single test target with the `-only` option:

```
path/to/xctool.sh \
  -workspace YourWorkspace.xcworkspace \
  -scheme YourScheme \
  build-tests -only SomeTestTarget
```

#### Running Tests

If you've already built tests with __build-tests__, you can use
__run-tests__ to run them.  This is helpful if you want to build tests
once, but run them against multiple SDKs.

To run all tests, you would use:

```
path/to/xctool.sh \
  -workspace YourWorkspace.xcworkspace \
  -scheme YourScheme \
  run-tests
```

Just as with the __test__ action, you can limit which tests are run with
the `-only` option.  And, you can change which SDK they're run against
with the `-test-sdk` option.

## Contributing

Bug fixes, improvements, and especially new
[Reporter](https://github.com/facebook/xctool/blob/master/xctool/xctool/Reporter.h)
implementations are welcome.  Submit a [pull
request](https://help.github.com/articles/using-pull-requests).

