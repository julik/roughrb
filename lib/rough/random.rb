# frozen_string_literal: true

module Rough
  # Seeded pseudo-random number generator using Park-Miller LCG.
  # Produces deterministic sequences for a given seed, matching
  # the JavaScript rough.js implementation exactly.
  class Random
    def initialize(seed)
      @seed = seed.to_i
    end

    def next
      if @seed != 0
        # Match JS: (2**31 - 1) & Math.imul(48271, seed)
        # Math.imul truncates to 32-bit signed int, then & masks to 31 bits
        product = (48271 * @seed) & 0xFFFFFFFF
        # Convert to signed 32-bit (as JS Math.imul does)
        product -= 0x100000000 if product >= 0x80000000
        @seed = (2**31 - 1) & product
        @seed.to_f / 2**31
      else
        Kernel.rand
      end
    end

    def self.new_seed
      rand(2**31)
    end
  end
end
