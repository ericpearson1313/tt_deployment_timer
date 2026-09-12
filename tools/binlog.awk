# Lookup table for hex → 4-bit binary
function hex2bin(h,    map) {
    map["0"]="0000"; map["1"]="0001"; map["2"]="0010"; map["3"]="0011";
    map["4"]="0100"; map["5"]="0101"; map["6"]="0110"; map["7"]="0111";
    map["8"]="1000"; map["9"]="1001"; map["A"]="1010"; map["B"]="1011";
    map["C"]="1100"; map["D"]="1101"; map["E"]="1110"; map["F"]="1111";
    map["a"]="1010"; map["b"]="1011"; map["c"]="1100"; map["d"]="1101";
    map["e"]="1110"; map["f"]="1111";
    return map[h]
}

{
    # For each hex word on the line
    for (i = 1; i <= NF; i++) {
        hex = $i
        bin = ""

        # Convert each hex digit to 4-bit binary
        for (j = 1; j <= length(hex); j++) {
            c = substr(hex, j, 1)
            bin = bin hex2bin(c)
        }

        print bin
    }
}
