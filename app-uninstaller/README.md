
## app-uninstaller

__app-uninstaller__ is a helper app we use to uninstall apps from the
iOS simulator.

Before starting a TEST_HOST app, __xctool__ will first install this
helper app to the simulator, start it, and ask it to uninstall the
TEST_HOST app.  This way each application test is run with a fresh
install of the TEST_HOST with no prior state.
