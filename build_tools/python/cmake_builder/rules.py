## Copyright 2022 The IREE Authors
#
# Licensed under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
"""Helpers that build CMake rules.

Each function takes a list of parameters and returns a string ready to be
included in a CMakeLists.txt file. Builder functions handle optional arguments,
lists, formatting, etc.

For example:

build_iree_fetch_artifact(
    target_name="abcd",
    source_url="https://example.com/abcd.tflite",
    output="./abcd.tflite",
    unpack=True)

Outputs:

iree_fetch_artifact(
  NAME
    "abcd"
  SOURCE_URL
    "https://example.com/abcd.tflite"
  OUTPUT
    "./abcd.tflite"
  UNPACK
)
"""

from typing import List, Optional, Sequence

INDENT_SPACES = " " * 2


def _get_string_list(values: List[str], quote: bool = True) -> List[str]:
  if quote:
    values = [f'"{value}"' for value in values]
  return values


def _get_block_body(body: List[str]) -> List[str]:
  return [INDENT_SPACES + line for line in body]


def _get_string_arg_block(keyword: str,
                          value: Optional[str],
                          quote: bool = True) -> List[str]:
  if value is None:
    return []
  if quote:
    value = f'"{value}"'
  return [keyword] + _get_block_body([value])


def _get_string_list_arg_block(keyword: str,
                               values: List[str],
                               quote: bool = True) -> List[str]:
  if len(values) == 0:
    return []
  body = _get_string_list(values, quote)
  return [keyword] + _get_block_body(body)


def _get_option_arg_block(keyword: str, value: Optional[bool]) -> List[str]:
  if value is True:
    return [keyword]
  return []


def _build_call_rule(rule_name: str,
                     parameter_blocks: Sequence[List[str]]) -> List[str]:
  output = [f"{rule_name}("]
  for block in parameter_blocks:
    if len(block) == 0:
      continue
    output.extend(_get_block_body(block))
  output.append(")")
  return output


def _convert_block_to_string(block: List[str]) -> str:
  # Hack to append the terminating newline and only copies the list instead of
  # the whole string.
  return "\n".join(block + [""])


def build_iree_bytecode_module(target_name: str,
                               src: str,
                               module_name: str,
                               flags: List[str] = [],
                               compile_tool_target: Optional[str] = None,
                               c_identifier: Optional[str] = None,
                               static_lib_path: Optional[str] = None,
                               deps: List[str] = [],
                               testonly: bool = False,
                               public: bool = True) -> str:
  name_block = _get_string_arg_block("NAME", target_name)
  src_block = _get_string_arg_block("SRC", src)
  module_name_block = _get_string_arg_block("MODULE_FILE_NAME", module_name)
  c_identifier_block = _get_string_arg_block("C_IDENTIFIER", c_identifier)
  static_lib_block = _get_string_arg_block("STATIC_LIB_PATH", static_lib_path)
  compile_tool_target_block = _get_string_arg_block("COMPILE_TOOL",
                                                    compile_tool_target)
  flags_block = _get_string_list_arg_block("FLAGS", flags)
  deps_block = _get_string_list_arg_block("DEPS", deps)
  testonly_block = _get_option_arg_block("TESTONLY", testonly)
  public_block = _get_option_arg_block("PUBLIC", public)
  return _convert_block_to_string(
      _build_call_rule(rule_name="iree_bytecode_module",
                       parameter_blocks=[
                           name_block, src_block, module_name_block,
                           c_identifier_block, compile_tool_target_block,
                           static_lib_block, flags_block, deps_block,
                           testonly_block, public_block
                       ]))


def build_iree_fetch_artifact(target_name: str, source_url: str, output: str,
                              unpack: bool) -> str:
  name_block = _get_string_arg_block("NAME", target_name)
  source_url_block = _get_string_arg_block("SOURCE_URL", source_url)
  output_block = _get_string_arg_block("OUTPUT", output)
  unpack_block = _get_option_arg_block("UNPACK", unpack)
  return _convert_block_to_string(
      _build_call_rule(rule_name="iree_fetch_artifact",
                       parameter_blocks=[
                           name_block, source_url_block, output_block,
                           unpack_block
                       ]))


def build_iree_import_tf_model(target_path: str, source: str,
                               entry_function: str,
                               output_mlir_file: str) -> str:
  target_name_block = _get_string_arg_block("TARGET_NAME", target_path)
  source_block = _get_string_arg_block("SOURCE", source)
  entry_function_block = _get_string_arg_block("ENTRY_FUNCTION", entry_function)
  output_mlir_file_block = _get_string_arg_block("OUTPUT_MLIR_FILE",
                                                 output_mlir_file)
  return _convert_block_to_string(
      _build_call_rule(rule_name="iree_import_tf_model",
                       parameter_blocks=[
                           target_name_block, source_block,
                           entry_function_block, output_mlir_file_block
                       ]))


def build_iree_import_tflite_model(target_path: str, source: str,
                                   output_mlir_file: str) -> str:
  target_name_block = _get_string_arg_block("TARGET_NAME", target_path)
  source_block = _get_string_arg_block("SOURCE", source)
  output_mlir_file_block = _get_string_arg_block("OUTPUT_MLIR_FILE",
                                                 output_mlir_file)
  return _convert_block_to_string(
      _build_call_rule(rule_name="iree_import_tflite_model",
                       parameter_blocks=[
                           target_name_block, source_block,
                           output_mlir_file_block
                       ]))


def build_add_dependencies(target: str, deps: List[str]) -> str:
  if len(deps) == 0:
    raise ValueError("Target dependencies can't be empty.")
  deps_list = _get_string_list(deps, quote=False)
  return _convert_block_to_string([f"add_dependencies({target}"] +
                                  _get_block_body(deps_list) + [")"])
