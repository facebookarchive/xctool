// These get included into the XCTest and OCUnit versions

describe(@"Some Description", ^{
  it(@"it something", ^{
  });

  it(@"it anotherthing", ^{
  });

  it(@"a duplicate name", ^{
    NSLog(@"Test will be named '-[KiwiTests_* SomeDescription_ADuplicateName]'");
  });

  it(@"a duplicate name", ^{
    NSLog(@"Test will be named '-[KiwiTests_* SomeDescription_ADuplicateName_2]'");
  });
});