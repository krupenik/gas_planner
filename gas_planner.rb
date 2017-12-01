#! /usr/bin/env ruby

class Gas
  DENSITY = {
    H2: 0.09,
    He: 0.179,
    N2: 1.251,
    O2: 1.428
  }.freeze

  PP_MAX = {
    normal: {
      O2: 1.4,
      N2: 5.0,
      He: 13.0
    }.freeze,

    deco: {
      O2: 1.6,
      N2: 5.0,
      He: 13.0
    }.freeze
  }.freeze

  SOLUBILITY = {
    H2: 0.048,
    He: 0.015,
    O2: 0.12,
    N2: 0.067
  }.freeze

  MIN_FRACTION = {
    H2: 0,
    He: 0,
    N2: 0.05,
    O2: 0.01,
  }.freeze

  IDEAL_DENSITY = 5.2
  MAX_DENSITY = 6.2

  class << self
    def pressure_at_depth(depth)
      (depth / 10.0) + 1
    end

    def gas_fraction_at_depth(gas, depth, mode = :normal)
      (100 * PP_MAX[mode][gas] / pressure_at_depth(depth)).floor / 100.0
    end

    def best_mix(depth, mode = :normal)
      o2 = gas_fraction_at_depth(:O2, depth, mode)
      n2 = [1 - o2, gas_fraction_at_depth(:N2, depth, mode)].min

      gas = new(o2, 1 - o2 - n2)

      while MAX_DENSITY <= gas.density_at_depth(depth) && gas.n2 > MIN_FRACTION[:N2]
        gas = new(gas.o2, gas.he + 0.01)
      end

      gas
    end

    def best_deco_mix(prev_gas, depth)
      deco_gas = best_mix(depth, :deco)

      while prev_gas.solubility < deco_gas.solubility
        deco_gas = new(deco_gas.o2, (deco_gas.he + 0.01).round(2))
      end

      deco_gas
    end
  end

  attr_reader :o2, :he, :n2

  def initialize(o2 = 0.21, he = 0, n2 = nil)
    @o2 = o2.round(2)
    @he = he.round(2)
    @n2 = (n2 || (1 - o2 - he)).round(2)
  end

  def to_s
    if @he > 0
      "%d/%d" % [@o2 * 100, @he * 100]
    else
      "EAN%d" % [@o2 * 100]
    end
  end

  def to_hash
    { O2: @o2, N2: @n2, He: @he }
  end

  def inert_hash
    { N2: @n2, He: @he }
  end

  def density
    to_hash.reduce(0) { |a, (el, amount)| a + DENSITY[el] * amount }
  end

  def solubility
    inert_hash.reduce(0) { |a, (el, amount)| a + SOLUBILITY[el] * amount }
  end

  def density_at_depth(depth)
    density * self.class.pressure_at_depth(depth)
  end

  def mod(mode = :normal)
    pp_max_pressure = to_hash.map { |el, fraction| PP_MAX[mode][el] / fraction }.min

    (((pp_max_pressure * [1.0, MAX_DENSITY / (density * pp_max_pressure)].min) - 1) * 10).floor
  end
end

