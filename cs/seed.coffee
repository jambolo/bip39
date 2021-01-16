# Generates the seed from a mnemonic phrase
#
# Command syntax:
#
#   seed [--passphrase <passphrase>] [--validate] [--language english] <mnemonic phrase>
#
# Options:
#
#   --passphrase - Passphrase. (optional)
#   --validate   - If specified, the mnemonic phrase is validated (optional).
#   --language   - The wordlist to be used to validate the mnemonic phrase (optional).

yargs = require 'yargs'
Crypto = require 'crypto'
bip39 = require './bip39'

validate = (mnemonic, language) ->
  return

args = yargs
  .usage '$0 <mnemonic..>', 'Generates a BIP-39 seed.'
  .help()
  .version()
  .option 'passphrase', {
    type: 'string'
    default: ''
    alias: 'p'
    describe: 'An passphrase used in generating the seed. (optional)'
  }
  .option 'validate', {
    type: 'boolean'
    alias: 'v'
    default: false
    describe: 'If included, the mnemonic phrase is validated.'
  }
  .option 'language', {
    type: 'string'
    choices: ['english']
    default: 'english'
    alias: 'l'
    describe: 'The wordlist to be used for validation. Currently, only english is supported. (optional)'
  }
  .check (argv) ->
    if argv.validate and argv.mnemonic.length % 3 != 0
      throw new Error 'The number words in the mnemonic must be a multiple of 3.'
    return true
  .argv

# Validate the mnemonic words if requested
if args.validate
  [ok, result] = bip39.decode args.mnemonic, args.language
  if not ok
    console.error "#{args.$0}: ", result
    process.exit 1

# Create the 'sentence' from the words
sentence = bip39.stringify(args.mnemonic)

# Generate the seed
seed = Crypto.pbkdf2Sync sentence, 'mnemonic' + args.passphrase, 2048, 64, 'sha512'

# Output the seed
process.stdout.write seed.toString('hex')
