# Encodes a value using BIP 39
#
# Command syntax:
# 
#     encode (wif|address|hex) [--words <number>] [--strict] [--language english] <input>
# 
# Options:
# 
#   Format:
#       hex    - Input is a hex value
#       base58 - Input is an address or private key encoded using base-58
#       base64 - Input is a base-64 value
#
#   --words <number> - Number of words to be generated. The input is
#                      truncated or padded with 0's if it doesn't match
#                      the the specified value. If --strict is
#                      specified and the input doesn't match, the
#                      encode will fail.
# 
#   --strict - The length of the input must match the number of words
#              (if specified).
#
#   --language - The wordlist to use. Currently, only english is
#                supported and it is the default.

yargs = require "yargs"
Base58 = require "base-58"
wordlists = require "./wordlists"

args = yargs
  .usage "$0 <format> <input>", "Encode a value using BIP 39", (yargs) ->
    yargs
      .positional "format", {
        type: "string"
        choices: ["hex", "base58", "base64"]
        describe: "Input format"
      }
      .positional "input", {
        type: "string"
        describe: "Input to encode"
      }
  .help()
  .version()
  .option "words", {
    type: "number"
    alias: "n"
    describe: "Number of words to be generated. The input is truncated or padded with 0's if it doesn't match
               the the specified value. The number of words must be a multiple of 3 and must be greater than 0.
               If --strict is specified and the input doesn't match, the encode will fail."
  }
  .option "strict", {
    type: "boolean"
    default: false
    alias: "s"
    describe: "The length of the input must match the number of words (if specified)."
  }
  .option "language", {
    type: "string"
    choices: ["english"]
    default: "english"
    alias: "l"
    describe: "The wordlist to use. Currently, only english is supported and it is the default."
  }
  .check (argv) ->
    if argv.words? and (argv.words <= 0 or argv.words % 3 != 0)
      throw new Error("The number of words must be positive and a multiple of 3.")
    return true
  .argv

console.log "format=#{args.format}, words=#{args.words}, strict=#{args.strict}, language=#{args.language}, input='#{args.input}'"

switch args.format
  when "hex" then input = Buffer.from args.input, "hex"
  when "base58" then input = Base58.decode  args.input
  when "base64" then input = Buffer.from args.input, "base64"

if args.strict and args.words? and input.length != args.words / 3 * 4
  console.error "The size of the input does not correspond exactly to the requested number of words."
  process.exit 1

console.log input


if input.length % 4 != 0
  pad = 
