pragma solidity ^0.5.0;

contract EllipticCurve {

  uint256 constant gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
  uint256 constant gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;
  // n is known as P
  uint256 constant n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
  uint256 constant a = 0;
  uint256 constant b = 7;

  function _jAdd(uint256 x1, uint256 z1, uint256 x2, uint256 z2) public pure returns (uint256 x3, uint256 z3) {
    (x3, z3) = (addmod(mulmod(z2, x1, n), mulmod(x2, z1, n), n), mulmod(z1, z2, n)
    );
  }

  function _jSub(uint256 x1, uint256 z1, uint256 x2, uint256 z2) public pure returns (uint256 x3, uint256 z3) {
    (x3, z3) = (addmod(mulmod(z2, x1, n), mulmod(n - x2, z1, n), n), mulmod(z1, z2, n));
  }

  function _jMul(uint256 x1, uint256 z1, uint256 x2, uint256 z2) public pure returns (uint256 x3, uint256 z3) {
    (x3, z3) = (mulmod(x1, x2, n), mulmod(z1, z2, n));
  }

  function _jDiv(uint256 x1, uint256 z1, uint256 x2, uint256 z2) public pure returns (uint256 x3, uint256 z3) {
    (x3, z3) = (mulmod(x1, z2, n), mulmod(z1, x2, n));
  }

  function _inverse(uint256 _a) public pure returns (uint256 invA) {
    uint256 t = 0;
    uint256 newT = 1;
    uint256 r = n;
    uint256 newR = _a;
    uint256 q;
    while (newR != 0) {
      q = r / newR;
      (t, newT) = (newT, addmod(t, (n - mulmod(q, newT, n)), n));
      (r, newR) = (newR, r - q * newR);
    }
    return t;
  }

  function _ecAdd(uint256 x1, uint256 y1, uint256 z1, uint256 x2, uint256 y2, uint256 z2) public pure
  returns (uint256 x3, uint256 y3, uint256 z3) {
    uint256 _l;
    uint256 lz;
    uint256 da;
    uint256 db;

    if ((x1 == 0) && (y1 == 0)) {
      return (x2, y2, z2);
    }

    if ((x2 == 0) && (y2 == 0)) {
      return (x1, y1, z1);
    }

    if ((x1 == x2) && (y1 == y2)) {
      (_l, lz) = _jMul(x1, z1, x1, z1);
      (_l, lz) = _jMul(_l, lz, 3, 1);
      (_l, lz) = _jAdd(_l, lz, a, 1);

      (da, db) = _jMul(y1, z1, 2, 1);
    } else {
      (_l, lz) = _jSub(y2, z2, y1, z1);
      (da, db) = _jSub(x2, z2, x1, z1);
    }

    (_l, lz) = _jDiv(_l, lz, da, db);

    (x3, da) = _jMul(_l, lz, _l, lz);
    (x3, da) = _jSub(x3, da, x1, z1);
    (x3, da) = _jSub(x3, da, x2, z2);

    (y3, db) = _jSub(x1, z1, x3, da);
    (y3, db) = _jMul(y3, db, _l, lz);
    (y3, db) = _jSub(y3, db, y1, z1);

    if (da != db) {
      x3 = mulmod(x3, db, n);
      y3 = mulmod(y3, da, n);
      z3 = mulmod(da, db, n);
    } else {
      z3 = da;
    }
  }

  function _ecDouble(uint256 x1, uint256 y1, uint256 z1) public pure returns (uint256 x3, uint256 y3, uint256 z3) {
    (x3, y3, z3) = _ecAdd(x1, y1, z1, x1, y1, z1);
  }

  function _ecMul(uint256 d, uint256 x1, uint256 y1, uint256 z1) public pure returns (uint256 x3, uint256 y3, uint256 z3) {
    uint256 remaining = d;
    uint256 px = x1;
    uint256 py = y1;
    uint256 pz = z1;
    uint256 acx = 0;
    uint256 acy = 0;
    uint256 acz = 1;

    if (d == 0) {
      return (0, 0, 1);
    }

    while (remaining != 0) {
      if ((remaining & 1) != 0) {
        (acx, acy, acz) = _ecAdd(acx, acy, acz, px, py, pz);
      }
      remaining = remaining / 2;
      (px, py, pz) = _ecDouble(px, py, pz);
    }

    (x3,y3,z3) = (acx, acy, acz);
  }

  function derivePublicKey(uint256 privKey) public pure returns (uint256 qx, uint256 qy) {
    uint256 x;
    uint256 y;
    uint256 z;
    (x, y, z) = _ecMul(privKey, gx, gy, 1);
    z = _inverse(z);
    qx = mulmod(x, z, n);
    qy = mulmod(y, z, n);
  }

  function deriveKey(uint256 privKey, uint256 pubX, uint256 pubY) public pure returns (uint256 qx, uint256 qy) {
    (uint256 x, uint256 y, uint256 z) = _ecMul(privKey, pubX, pubY, 1);
    z = _inverse(z);
    qx = mulmod(x, z, n);
    qy = mulmod(y, z, n);
  }

  //TODO: review code
  /// @dev Modular exponentiation, b^e % m
  /// Basically the same as can be found here:
  /// https://github.com/ethereum/serpent/blob/develop/examples/ecc/modexp.se
  /// @param base The base.
  /// @param e The exponent.
  /// @param m The modulus.
  /// @return x such that x = b**e (mod m)
  function expmod(uint base, uint e, uint m) internal pure returns (uint r) {
    if (base == 0)
      return 0;
    if (e == 0)
      return 1;
    if (m == 0)
      revert("Modulus by zero");
    r = 1;
    uint bit = 2 ** 255;
    assembly {
      for { } gt(bit, 0) { }{
        r := mulmod(mulmod(r, r, m), exp(base, iszero(iszero(and(e, bit)))), m)
        r := mulmod(mulmod(r, r, m), exp(base, iszero(iszero(and(e, div(bit, 2))))), m)
        r := mulmod(mulmod(r, r, m), exp(base, iszero(iszero(and(e, div(bit, 4))))), m)
        r := mulmod(mulmod(r, r, m), exp(base, iszero(iszero(and(e, div(bit, 8))))), m)
        bit := div(bit, 16)
      }
    }
  }

  // function inverseMod(uint u) public pure returns (uint)
  // {
  //   if (u == 0 || u == n || n == 0)
  //       return 0;
  //   if (u > n)
  //       u = u % n;

  //   int t1;
  //   int t2 = 1;
  //   uint r1 = n;
  //   uint r2 = u;
  //   uint q;

  //   while (r2 != 0) {
  //     q = r1 / r2;
  //     (t1, t2, r1, r2) = (t2, t1 - int(q) * t2, r2, r1 - q * r2);
  //   }

  //   if (t1 < 0)
  //     return (n - uint(-t1));

  //   return uint(t1);
  // }

  // TODO: review why not to do a modulo
  function _inv(uint256 x1, uint256 y1) public pure returns (uint256 x3, uint256 y3) {
    (x3, y3) = (x1, (n - y1) % n);
  }

  function add(uint256 pubX1, uint256 pubY1, uint256 pubX2, uint256 pubY2) public pure
    returns(uint256 qx, uint256 qy)
  {
    uint256 x;
    uint256 y;
    uint256 z;
    (x,y,z) = _ecAdd(pubX1, pubY1, 1, pubX2, pubY2, 1);
    z = _inverse(z);
    qx = mulmod(x, z, n);
    qy = mulmod(y, z, n);
  }

  function sub(uint256 pubX1, uint256 pubY1, uint256 pubX2, uint256 pubY2) public pure
    returns(uint256 qx, uint256 qy)
  {
    (uint256 x2, uint256 y2) = _inv(pubX2, pubY2);
    (qx, qy) = add(pubX1, pubY1, x2, y2);
  }

}