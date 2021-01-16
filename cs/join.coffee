# Command syntax
#
#   join [--language <language>] [--json] (sss|xor)
#
# Methods (one must be specified)
#
#   sss   Shamir's Secret Sharing
#   xor   XOR
#
# Options
#
#   --language, -l    The wordlist to be used. Currently, only *english* is supported and it is the default.
#                     (optional)
#   --json, -j        Outputs the words in json format. (optional)
#
# The shares are read from stdin, one per line and joined using SSS or the XOR method. Note that while the share
# phrases are validated according to BIP-39, there is no way to ensure that the value recreated by joining
# shares matches the original value.

yargs = require 'yargs'
Base58 = require 'base-58'
Crypto = require 'crypto'
readline = require 'readline'
bip39 = require './bip39'

class Mod
  @add: (a, b, m) -> (a + b) % m
  @sub: (a, b, m) -> (a + (m - b)) % m
  @neg: (a, m) -> (m - a) % m
  @mul: (a, b, m) -> (a * b) % m
  @div: (a, b, m) -> (a * @inv(b, m)) % m

  # https://en.wikipedia.org/wiki/Modular_multiplicative_inverse#Extended_Euclidean_algorithm
  @inv: (a, m) ->
    [ gcd, x, y ] = @xgcd a, m
    return (m + x) % m

  # https://en.wikipedia.org/wiki/Extended_Euclidean_algorithm
  @xgcd: (a, b) ->
    x = 1n
    x1 = 0n
    y = 0n
    y1 = 1n
    while b > 0
      q = a / b
      [ a, b ] = [ b, a % b ]
      [ x, x1 ] = [ x1, x - q * x1 ]
      [ y, y1 ] = [ y1, y - q * y1 ]
    return [ a, x, y ]

# Joins shares using the XOR method
xor = (shares) ->
  joined = Buffer.from shares[0]
  for i in [1...shares.length]
    share = shares[i]
    joined[j] ^= share[j] for j in [0...joined.length]
  return joined

# https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing
sss = (shares) ->
  p = 999999999989n # Biggest prime I could find. Must be 2^32-1 < p < 2^48 and must match share.coffee.

  L0 = (xs, ys) ->
    sum = 0n
    for j in [0...xs.length]
      product = 1n
      for m in [0...xs.length] when m isnt j
        product = Mod.mul(product, Mod.div(xs[m], Mod.sub(xs[m], xs[j], p), p), p)
      sum = Mod.add(sum, Mod.mul(ys[j], product, p), p)
    return sum

  nBlocks = shares[0].length / 8
  joined = Buffer.allocUnsafe nBlocks * 4
  for b in [0...nBlocks]
    xs = []
    ys = []
    for share in shares
      x = BigInt(share.readUInt16BE(b * 8 + 6))
      y = (BigInt(share.readUInt32BE(b * 8 + 0)) << 16n) + BigInt(share.readUInt16BE(b * 8 + 4))
      xs.push x
      ys.push y
    block = L0 xs, ys
    joined.writeUInt32BE Number(block), b * 4
  return joined

# Configure the command line processing
args = yargs
  .usage '$0 <method>',
    "Use Shamir's Secret Sharing or XOR methods to recreate the original mnemonic phrase from shares read from stdin",
    (yargs) ->
      yargs
        .positional 'method', {
          type: 'string'
          choices: ['sss', 'xor']
          describe: 'Method'
        }
  .help()
  .version()
  .option 'language', {
    type: 'string'
    choices: ['english']
    default: 'english'
    alias: 'l'
    describe: 'The wordlist to be used. Currently, only english is supported. (optional)'
  }
  .option 'json', {
    type: 'boolean'
    default: false
    alias: 'j'
    describe: 'The words are listed in JSON format.'
  }
  .argv

shares = []
rl = readline.createInterface { input: process.stdin }
rl.on 'line', (line) ->
  phrase = line.trim().split ' '
  shares.push phrase

rl.on 'close', ->
  decoded = []
  for share in shares
    [ok, result] = bip39.decode share, args.language
    if not ok
      console.error "#{args.$0}: ", result
      process.exit 1
    decoded.push result

  # Generate the shares
  switch args.method
    when 'sss' then joined = sss decoded
    when 'xor' then joined = xor decoded

  # BIP-39 encode the joined shares
  words = bip39.encode joined, args.language

  # Output
  if args.json
    process.stdout.write JSON.stringify(words)
  else
    process.stdout.write bip39.stringify(words)
