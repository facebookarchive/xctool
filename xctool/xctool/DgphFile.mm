//
// Copyright 2004-present Facebook. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <Foundation/Foundation.h>
#include "DgphFile.h"

#include <fstream>
#include <vector>

namespace {

std::string pTake(std::ifstream &stream, int count) {
  std::string result(count, '\0');
  stream.read(&result[0], count);
  return std::move(result);
}

/*! Parse a 7 bit little endian variable length encoded number.

 The encoding takes 7 bit blocks of the number and encodes it in a byte,
 and set the msb of that byte to 1 if there are additional bytes to follow.

 For example, a hypothetical 4 byte number encodes as follows:

   0000 0000 0000z zzzz zzyy yyyy yxxx xxxx

   1xxxxxxx 1yyyyyyy 0zzzzzzz
    ^msb  ^lsb
 */
uint64_t pVarLenIntLE(std::ifstream &stream) {
  uint64_t result = 0;
  int shiftNew = 0;
  int byte;
  do {
    byte = stream.get();
    result |= (byte & 0x7f) << shiftNew;
    shiftNew+=7;
    if (shiftNew > 7 * 8) {
      throw std::runtime_error("Variable length number seems too big.");
    }
  } while(byte & 0x80);
  return result;
}

std::string pVarLenPrefixedString(std::ifstream &stream) {
  uint64_t len = pVarLenIntLE(stream);
  if (len > 200000000) {
    // avoid allocating too much
    throw std::runtime_error("length-prefixed string seems too long.");
  }
  return pTake(stream, (int)len);
}

/*! Read a variable length integer length prefixed string, but ignore output.
 */
void pVarLenPrefixedString_(std::ifstream &stream) {
  uint64_t len = pVarLenIntLE(stream);
  stream.ignore(len);
}

template<class F>
auto pVarLenPrefixedList(std::ifstream &stream, F func) -> std::vector<decltype(func(stream))> {
  uint64_t len = pVarLenIntLE(stream);
  std::vector<decltype(func(stream))> items;
  for (uint64_t i = 0; i < len; i++) {
    items.emplace_back(func(stream));
  }
  return std::move(items);
}

/*! Read a variable length integer length prefixed list, but ignore output.
 */
template<class F>
void pVarLenPrefixedList_(std::ifstream &stream, F func) {
  uint64_t len = pVarLenIntLE(stream);
  for (uint64_t i = 0; i < len; i++) {
    func(stream);
  }
}

DgphFile parseDgph104(std::ifstream &input) {
  pVarLenPrefixedString_(input); // build date
  pVarLenPrefixedString_(input); // build time

  pVarLenPrefixedList_(input, [](std::ifstream &input) {
    int isVirtual = input.get();
    if (!isVirtual) {
      pVarLenIntLE(input); // parent node id
    }
    pVarLenPrefixedString_(input); // node name
  });

  pVarLenIntLE(input); // fsroot node id
  pVarLenIntLE(input); // projectroot node id

  // node states ignored
  pVarLenPrefixedList_(input, [](std::ifstream &input) {
    pVarLenIntLE(input); // node id
    pVarLenIntLE(input); // options
    uint64_t err = pVarLenIntLE(input); // err
    if (!err) {
      pVarLenIntLE(input); // mtime
      pVarLenIntLE(input); // size
      pVarLenIntLE(input); // mode
    }
  });

  auto invocations = pVarLenPrefixedList(input, [](std::ifstream &input) -> std::vector<std::string> {
    pVarLenPrefixedString_(input); // identifier
    input.ignore(16); // signature hash
    pVarLenPrefixedString_(input); // desc
    auto args = pVarLenPrefixedList(input, pVarLenPrefixedString);
    pVarLenPrefixedList_(input, pVarLenPrefixedString_); // env
    pVarLenIntLE(input); // working dir node id
    input.ignore(8); // start time double
    input.ignore(8); // end time double
    pVarLenIntLE(input); // exitStatus
    pVarLenPrefixedString_(input); // builder uuid
    pVarLenPrefixedString_(input); // activity log (SLF0 encoded)
    pVarLenPrefixedList_(input, pVarLenIntLE); // input node ids
    pVarLenPrefixedList_(input, pVarLenIntLE); // output node ids
    return std::move(args);
  });

  return DgphFile(std::move(invocations));
}

DgphFile parseDgph100(std::ifstream &input) {
  pVarLenPrefixedString_(input); // build date
  pVarLenPrefixedString_(input); // build time

  pVarLenPrefixedList_(input, [](std::ifstream &input) {
    int isVirtual = input.get();
    if (!isVirtual) {
      pVarLenIntLE(input); // parent node id
    }
    pVarLenPrefixedString_(input); // node name
  });

  pVarLenIntLE(input); // fsroot node id
  pVarLenIntLE(input); // projectroot node id

  auto invocations = pVarLenPrefixedList(input, [](std::ifstream &input) -> std::vector<std::string> {
    pVarLenPrefixedString_(input); // identifier
    input.ignore(16); // signature hash
    pVarLenPrefixedString_(input); // desc
    auto args = pVarLenPrefixedList(input, pVarLenPrefixedString);
    pVarLenPrefixedList_(input, pVarLenPrefixedString_); // env
    pVarLenIntLE(input); // working dir node id
    input.ignore(8); // start time double
    input.ignore(8); // end time double
    pVarLenIntLE(input); // exitStatus
    pVarLenPrefixedString_(input); // builder uuid
    pVarLenPrefixedString_(input); // activity log (SLF0 encoded)
    // input node states
    pVarLenPrefixedList_(input, [](std::ifstream &input) {
      pVarLenIntLE(input); // node id
      pVarLenIntLE(input); // options
      uint64_t err = pVarLenIntLE(input); // err
      if (!err) {
        pVarLenIntLE(input); // mtime
        pVarLenIntLE(input); // size
        pVarLenIntLE(input); // mode
      }
    });
    return std::move(args);
  });

  return DgphFile(std::move(invocations));
}

} // anonymous namespace

DgphFile DgphFile::loadFromFile(const char *path) {
  std::ifstream input(path);
  input.exceptions(std::ifstream::failbit | std::ifstream::badbit);

  try {
    std::string magicversion = pTake(input, 8);
    if (magicversion == "DGPH1.04") {  // Used for xcode 7
      return parseDgph104(input);
    } else if (magicversion == "DGPH1.00") {  // Used for xcode 6
      return parseDgph100(input);
    } else if (magicversion.find("DGPH") == 0) {
      NSLog(@"Unsupported version of DGPH file: %s, %s", magicversion.c_str(), path);
      return DgphFile();
    } else {
      NSLog(@"input is not a DGPH file: %s", path);
    }
  } catch (const std::exception &e) {
    NSLog(@"DGPH failed to load: %s, %s", e.what(), path);
    return DgphFile();
  }
  NSLog(@"DGPH failed to load: %s", path);
  return DgphFile();
}
