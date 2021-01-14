# Command syntax
#
#   share sss <M> <N> [--language english] <mnemonic phrase>
#   share xor <N> [--language english] <mnemonic phrase>
#
# Methods
#
#   sss   Shamir's Secret Sharing
#   xor   XOR
#
# Sharing Parameters
#
#   M     Minimum shares necessary to recreate the original. This number must be less than or equal to N.
#   N     Number of shares
#
# Options
#
#   --language, -l    The wordlist to be used. Currently, only english is supported and it is the default. (optional)
#   --json
#
# One method of sharing is a secret is Shamir's Secret Sharing (SSS). A description can be found here:
# https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing. Using SSS, you can generate N shares, of which M are
# required in order to recreate the original mnemonic.
#
# Another method for for sharing a secret is called the XOR method. This implementation is based on the implementation
# described here: https://github.com/mmgen/mmgen/wiki/XOR-Seed-Splitting:-Theory-and-Practice. In this scheme, all
# shares are required, so M is N.
#
# This program decodes the mnemonic and generates the shares, which are then re-encoded. Note that while the encoded
# share phrases have the standard BIP-39 error-detection, there is no way to ensure that the value recreated by joining
# shares matches the original value.

yargs = require 'yargs'
Base58 = require 'base-58'
Crypto = require 'crypto'
wordlists = require './wordlists'
bip39 = require './bip39'

# Creates n shares of the input using the XOR method
xor = (input, n) ->
  size = input.length

  # The first n-1 shares are just random
  shares = (Crypto.randomBytes(size) for [0...n - 1]) # this should be deterministic

  # The last share is the input XORed with all the other shares
  last = Buffer.from input
  for share in shares
    for i in [0...size]
      last[i] ^= share[i]
  shares.push last

  return shares

sss = (input, m, n) ->
  p = 999999999989n # Biggest prime I could find. Must be 2^32-1 < p < 2^48 and must match join.coffee.

  f = (x, s, coeffs) ->
    xn = BigInt(x)
    y = BigInt(s)
    for c in coeffs
      y = (y + xn * c) % p
      xn = (xn * BigInt(x)) % p
    return y

  coefficients = (k) ->
    coeffs = []
    for [0...k]
      r = Crypto.randomBytes 8 # this should be deterministic
      c0 = BigInt(r.readUInt32BE(0))
      c1 = BigInt(r.readUInt32BE(4))
      coeffs.push ((c0 << 32n) + c1) % p
    return coeffs

  nBlocks = input.length / 4
  shares = (Buffer.allocUnsafe(nBlocks * 8) for [0...n])
  for b in [0...nBlocks]
    block = input.readUInt32BE b * 4
    coeffs = coefficients m - 1
    for share, i in shares
      x = i + 1
      y = f x, block, coeffs
      y0 = Number(y >> 16n)
      y1 = Number(y & 0xffffn)
      share.writeUInt32BE y0, b * 8 + 0
      share.writeUInt16BE y1, b * 8 + 4
      share.writeUInt16BE x, b * 8 + 6
  return shares

# Configure the command line processing
args = yargs
  .usage '$0 <method> <args..>'
  .command 'sss <M> <N> <mnemonic..>', "Use Shamir's Secret Sharing to share a mnemonic phrase (default)", (yargs) ->
    yargs
      .positional 'M', {
        type: 'number'
        describe: 'Threshold'
      }
      .positional 'N', {
        type: 'number'
        describe: 'Number of shares'
      }
      .positional 'mnemonic', {
        type: 'string'
        describe: 'The mnemonic phrase'
      }
  .command 'xor <N> <mnemonic..>', 'Use XOR to share a mnemonic phrase', (yargs) ->
    yargs
      .positional 'N', {
        type: 'number'
        describe: 'Number of shares'
      }
      .positional 'mnemonic', {
        type: 'string'
        describe: 'The mnemonic phrase'
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
  .option 'json', {
    type: 'boolean'
    default: false
    alias: 'j'
    describe: 'The words are listed in JSON format.'
  }
  .check (argv) ->
    if argv._.length < 1
      throw new Error "Missing method."
    if argv._[0] != 'sss' and argv._[0] != 'xor'
      throw new Error "'#{argv._[0]}' is an invalid method."
    if argv.mnemonic.length < 3 or argv.mnemonic.length % 3 != 0
      throw new Error 'The number of words must be a multiple of 3 and at least 3.'
    if argv.N < 2 or argv.N > 65535
      throw new Error 'The number of shares, N, must be at least 2 and no greater than 65535.'
    if argv.M? and (argv.M < 1 or argv.M > argv.N)
      throw new Error 'The threshold value, M, must be at least 1 and cannot be greater than the number of shares, N.'
    return true
  .argv


[ok, result] = bip39.decode args.mnemonic, args.language
if not ok
  console.error '#{args.$0}: ', result
  process.exit 1

# Generate the shares
switch args._[0]
  when 'sss' then shares = sss result, args.M, args.N
  when 'xor' then shares = xor result, args.N

# BIP-39 encode the shares
phrases = (bip39.encode share, args.language for share in shares)

# Output

if args.json
  process.stdout.write JSON.stringify(phrases)
else
  for phrase in phrases
    process.stdout.write w + ' ' for w in phrase[0...-1]
    process.stdout.write phrase[phrase.length - 1] + '\n'
