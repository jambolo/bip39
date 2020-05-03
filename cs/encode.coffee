# Encodes a value using BIP 39
#
# Command syntax:
# 
#     encode (wif|address|hex) [--words <number>] [--strict] [--language english] <input>
# 
# Options:
# 
#   Format:
#       wif     - Input is a 256-bit value in WIF format
#       address - Input is a 160-bit value in base58check format
#       hex     - Input is a hex value of arbitrary length
#
#   --words <number> - Number of words to be generated. The input is
#                      truncated or padded with 0's if it doesn't match
#                      the the specified value. If --strict is
#                      specified and the input doesn't match, the
#                      encode will fail.
# 
#   --strict - The length of the input must match the number of words
#              (if specified) and the standard length of the input
#              type.
#
#   --language - The wordlist to use. Currently, only english is
#                supported and it is the default.

wordlists = require('./wordlists').wordlists
yargs = require 'yargs'
crypto = require 'crypto'

args = yargs
  .usage "$0 <format> <input>", "Encode a value using BIP 39", (yargs) ->
    yargs
      .positional "format", {
        type: "string"
        choices: ["hex", "wif", "address"]
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
    describe: "The length of the input must match the number of words (if specified) and the standard length of the input type."
  }
  .option "language", {
    type: "string"
    choices: ["english"]
    default: "english"
    alias: "l"
    describe: "The wordlist to use. Currently, only english is supported and it is the default."
  }
  .check (argv) ->
    if argv.words? and argv.words % 3 != 0
      throw new Error("The number of words must be a multiple of 3.")
    return true
  .argv

console.log "format=#{args.format}, words=#{args.words}, strict=#{args.strict}, language=#{args.language}, input='#{args.input}'"
