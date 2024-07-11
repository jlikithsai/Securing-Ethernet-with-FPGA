
# galois multiplication of the 4x4 matrix
def mixcolumns(state, isinv):
    # iterate over the 4 columns
    for i in range(4):
        # construct one column by slicing over the 4 rows
        column = state[i:i+16:4]
        # apply the mixcolumn on one column
        column = mixColumn(column, isinv)
        # put the values back into the state
        state[i:i+16:4] = column

    return state

# galois multiplication of 1 column of the 4x4 matrix
def mixColumn(column, isInv):
    if isInv: mult = [14, 11, 13, 9]
    else: mult = [2, 3, 1, 1]
    cpy = list(column)
    g = galois_multiplication

    column[0] = g(cpy[0], mult[0]) ^ g(cpy[3], mult[1]) ^ \
                g(cpy[2], mult[2]) ^ g(cpy[1], mult[3])
    column[1] = g(cpy[1], mult[0]) ^ g(cpy[0], mult[1]) ^ \
                g(cpy[3], mult[2]) ^ g(cpy[2], mult[3])
    column[2] = g(cpy[2], mult[0]) ^ g(cpy[1], mult[1]) ^ \
                g(cpy[0], mult[2]) ^ g(cpy[3], mult[3])
    column[3] = g(cpy[3], mult[0]) ^ g(cpy[2], mult[1]) ^ \
                g(cpy[1], mult[2]) ^ g(cpy[0], mult[3])
    return column


def galois_multiplication(a, b):
    """Galois multiplication of 8 bit characters a and b."""
    p = 0
    for counter in range(8):
        if b & 1: p ^= a
        hi_bit_set = a & 0x80
        a <<= 1
        # keep a 8 bit
        a &= 0xFF
        if hi_bit_set:
            a ^= 0x1b
        b >>= 1
    return p


x = mixcolumns( [200 if i==15 else 0 for i in range(16)], 0)
print([hex(y) for y in x])
print mixcolumns(x, 1)
print(galois_multiplication(200,2))
print(galois_multiplication(200,3))
