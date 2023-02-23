# @version 0.3.7

# Adapted from https://github.com/balancer-labs/balancer-v2-monorepo/blob/599b0cd8f744e1eabef3600d79a2c2b0aea3ddcb/pkg/solidity-utils/contracts/math/LogExpMath.sol

# powers of 10
E3: constant(int256)          = 1_000
E6: constant(int256)          = E3 * E3
E9: constant(int256)          = E3 * E6
E12: constant(int256)         = E3 * E9
E15: constant(int256)         = E3 * E12
E18: constant(int256)         = E3 * E15
E20: constant(int256)         = 100 * E18
MIN_NAT_EXP: constant(int256) = -41 * E18
MAX_NAT_EXP: constant(int256) = 130 * E18

# x_n = 2^(7-n), a_n = exp(x_n)
# in 20 decimals for n >= 2
X0: constant(int256)  = 128 * E18 # 18 decimals
A0: constant(int256)  = 38_877_084_059_945_950_922_200 * E15 * E18 # no decimals
X1: constant(int256)  = X0 / 2 # 18 decimals
A1: constant(int256)  = 6_235_149_080_811_616_882_910 * E6 # no decimals
X2: constant(int256)  = X1 * 100 / 2
A2: constant(int256)  = 7_896_296_018_268_069_516_100 * E12
X3: constant(int256)  = X2 / 2
A3: constant(int256)  = 888_611_052_050_787_263_676 * E6
X4: constant(int256)  = X3 / 2
A4: constant(int256)  = 298_095_798_704_172_827_474 * E3
X5: constant(int256)  = X4 / 2
A5: constant(int256)  = 5_459_815_003_314_423_907_810
X6: constant(int256)  = X5 / 2
A6: constant(int256)  = 738_905_609_893_065_022_723
X7: constant(int256)  = X6 / 2
A7: constant(int256)  = 271_828_182_845_904_523_536
X8: constant(int256)  = X7 / 2
A8: constant(int256)  = 164_872_127_070_012_814_685
X9: constant(int256)  = X8 / 2
A9: constant(int256)  = 128_402_541_668_774_148_407
X10: constant(int256) = X9 / 2
A10: constant(int256) = 11_331_4845_306_682_631_683
X11: constant(int256) = X10 / 2
A11: constant(int256) = 1_064_49_445_891_785_942_956

@external
@pure
def pow(_x: uint256, _y: uint256) -> uint256:
    # x^y

    if _y == 0:
        return convert(E18, uint256)

    if _x == 0:
        return 0
    
    assert shift(_x, -255) == 0 # dev: out of bounds

    # x^y = e^log(x^y)) = e^(y log x)
    # TODO: ln36
    l: int256 = self._log(convert(_x, int256)) * convert(_y, int256) / E18
    return convert(self._exp(l), uint256)

@external
@pure
def ln(a: uint256) -> int256:
    assert a > 0 # dev: out of bounds
    return self._log(convert(a, int256))

@external
@pure
def exponent(x: int256) -> int256:
    return self._exp(x)

@internal
@pure
def _log(_a: int256) -> int256:
    if _a < E18:
        # 1/a > 1, log(a) = -log(1/a)
        return -self.__log(E18 * E18 / _a)
    return self.__log(_a)

@internal
@pure
def __log(_a: int256) -> int256:
    # log a = sum(k_n x_n) + log(rem)
    #       = log(product(a_n^k_n) * rem)
    # k_n = {0,1}, x_n = 2^(7-n), log(a_n) = x_n
    a: int256 = _a
    s: int256 = 0

    # divide out a_ns
    if a >= A0 * E18:
        a /= A0
        s += X0
    if a >= A1 * E18:
        a /= A1
        s += X1
    
    # other terms are in 20 decimals
    a *= 100
    s *= 100

    if a >= A2:
        a = a * E20 / A2
        s += X2
    if a >= A3:
        a = a * E20 / A3
        s += X3
    if a >= A4:
        a = a * E20 / A4
        s += X4
    if a >= A5:
        a = a * E20 / A5
        s += X5
    if a >= A6:
        a = a * E20 / A6
        s += X6
    if a >= A7:
        a = a * E20 / A7
        s += X7
    if a >= A8:
        a = a * E20 / A8
        s += X8
    if a >= A9:
        a = a * E20 / A9
        s += X9
    if a >= A10:
        a = a * E20 / A10
        s += X10
    if a >= A11:
        a = a * E20 / A11
        s += X11

    # a < A11 (1.06), taylor series for remainder
    # z = (a - 1) / (a + 1)
    # c = log a = 2 * sum(z^(2n + 1) / (2n + 1))
    z: int256 = (a - E20) * E20 / (a + E20)
    zsq: int256 = z * z / E20
    n: int256 = z
    c: int256 = z

    n = n * zsq / E20
    c += n / 3
    n = n * zsq / E20
    c += n / 5
    n = n * zsq / E20
    c += n / 7
    n = n * zsq / E20
    c += n / 9
    n = n * zsq / E20
    c += n / 11

    c *= 2
    return (s + c) / 100

@internal
@pure
def _exp(_x: int256) -> int256:
    assert _x >= MIN_NAT_EXP and _x <= MAX_NAT_EXP
    if _x < 0:
        # exp(-x) = 1/exp(x)
        return E18 * E18 / self.__exp(-_x)
    return self.__exp(_x)

@internal
@pure
def __exp(_x: int256) -> int256:
    # e^x = e^(sum(k_n x_n) + rem)
    #     = product(e^(k_n x_n)) * e^(rem)
    #     = product(a_n^k_n) * e^(rem)
    # k_n = {0,1}, x_n = 2^(7-n), a_n = exp(x_n)
    x: int256 = _x

    # subtract out x_ns
    f: int256 = 1
    if x >= X0:
        x -= X0
        f = A0
    elif x >= X1:
        x -= X1
        f = A1

    # other terms are in 20 decimals
    x *= 100

    p: int256 = E20
    if x >= X2:
        x -= X2
        p = p * A2 / E20
    if x >= X3:
        x -= X3
        p = p * A3 / E20
    if x >= X4:
        x -= X4
        p = p * A4 / E20
    if x >= X5:
        x -= X5
        p = p * A5 / E20
    if x >= X6:
        x -= X6
        p = p * A6 / E20
    if x >= X7:
        x -= X7
        p = p * A7 / E20
    if x >= X8:
        x -= X8
        p = p * A8 / E20
    if x >= X9:
        x -= X9
        p = p * A9 / E20
    
    # x < X9 (0.25), taylor series for remainder
    # c = e^x = sum(x^n / n!)
    n: int256 = x
    c: int256 = E20 + x

    n = n * x / E20 / 2
    c += n
    n = n * x / E20 / 3
    c += n
    n = n * x / E20 / 4
    c += n
    n = n * x / E20 / 5
    c += n
    n = n * x / E20 / 6
    c += n
    n = n * x / E20 / 7
    c += n
    n = n * x / E20 / 8
    c += n
    n = n * x / E20 / 9
    c += n
    n = n * x / E20 / 10
    c += n
    n = n * x / E20 / 11
    c += n
    n = n * x / E20 / 12
    c += n

    return p * c / E20 * f / 100
