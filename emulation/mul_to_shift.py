def mul_to_shift(index, number):
    digits = bin(number)[2:][::-1]
    st = ""
    for x in range(len(digits)):
        if digits[x] == '1':
            st+="d"*x + "bytes["+index+"]"
            st+="^"
    return st


indices = [14,11,13,9]*4

for i in range(0, 12, 3):
    print(mul_to_shift("j", indices[i]))
    print(mul_to_shift("j+4", indices[i+1]))
    print(mul_to_shift("j+8", indices[i+2]))
    print(mul_to_shift("j+12", indices[i+3]))
    print('---')
