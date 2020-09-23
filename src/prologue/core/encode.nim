# Copyright 2020 Zeshen Xing
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


import base64, strutils


func base64Encode*[T: SomeInteger | char](s: openArray[T]): string {.inline.} =
  s.encode

proc base64Encode*(s: string): string {.inline.} =
  s.encode

func base64Decode*(s: string): string {.inline.} =
  s.decode

proc urlsafeBase64Encode*[T: SomeInteger | char](s: openArray[T]): string {.inline.} =
  ## URL-safe and Cookie-safe encoding.
  s.encode.replace('+', '-').replace('/', '_')

proc urlsafeBase64Encode*(s: string): string {.inline.} =
  ## URL-safe and Cookie-safe encoding.
  s.encode.replace('+', '-').replace('/', '_')

func urlsafeBase64Decode*(s: string): string {.inline.} =
  ## URL-safe and Cookie-safe decoding.
  s.replace('-', '+').replace('_', '/').decode
