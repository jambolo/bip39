# Decodes a mnemonic string back into the source value
#
# Command syntax:
#
#     decode (address|wif|base58|base64|hex) [--language english] <mnemonic phrase>
#
# Formats:
#
#   address - Decoded into a bitcoin address.
#   wif     - Decoded into a WIF-formatted private key.
#   base58  - Output format is base-58.
#   base64  - Output format is base-64.
#   hex     - Output format is hex.
#
# Options:
#
#   --language - The wordlist to be used to validate the mnemonic phrase (optional).

yargs = require 'yargs'
Base58 = require 'base-58'
Crypto = require 'crypto'
bip39 = require './bip39'

sha256 = (input) ->
  hash = Crypto.createHash 'sha256'
  hash.update input
  return hash.digest()

args = yargs
  .usage '$0 <format> <mnemonic..>', 'Decode a menmonic phrase using BIP-39', (yargs) ->
    yargs
      .positional 'format', {
        type: 'string'
        choices: ['address', 'wif', 'base58', 'base64', 'hex']
        describe: 'Output format'
      }
  .help()
  .version()
  .option 'language', {
    type: 'string'
    choices: ['english']
    default: 'english'
    alias: 'l'
    describe: 'The wordlist to be used for validation. Currently, only english is supported. (optional)'
  }
  .check (argv) ->
    if argv.mnemonic.length < 3 or argv.mnemonic.length > 768 or argv.mnemonic.length % 3 != 0
      throw new Error 'The number of words must be a multiple of and 3 between 3 and 768.'
    if argv.format is 'address' and argv.mnemonic.length != 21
      throw new Error 'A valid address must have 21 words.'
    if argv.format is 'wif' and argv.mnemonic.length != 30
      throw new Error 'A valid private key must have 30 words.'
    return true
  .argv

result = bip39.decode args.mnemonic, args.language
if not result.valid
  console.error '#{args.$0}: ', result.message
  process.exit 1

# Generate the output
switch args.format
  when 'address', 'wif'
    data = result.data
    actualLength = data[data.length - 1]
    output = Base58.encode data.slice(0, actualLength)
  when 'base58' then output = Base58.encode  data
  when 'base64' then output = data.toString 'base64'
  when 'hex' then output = data.toString 'hex'

process.stdout.write output
