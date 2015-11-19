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

#pragma once

#include <vector>
#include <string>

/*! DGPH files are serializations of xcode's internal build state.

 This is used in Xcode6 and 7.
 Previously, Xcode used build-state.dat.
 */
class DgphFile {
public:
  using Invocation = std::vector<std::string>;

  static DgphFile loadFromFile(const char *path);

  DgphFile(const DgphFile &) = delete;
  DgphFile(DgphFile &&other)
      : valid_(true), invocations_(std::move(other.invocations_)) {
    other.valid_ = false;
  }

  DgphFile(): valid_(false) {}
  DgphFile(std::vector<Invocation> &&invocations)
      : valid_(true), invocations_(std::move(invocations)) {}

  bool isValid() const {
    return valid_;
  }

  const std::vector<Invocation>& getInvocations() const {
    return invocations_;
  }

private:
  bool valid_;
  std::vector<Invocation> invocations_;
};
