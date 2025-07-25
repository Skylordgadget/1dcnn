adc_ref = 2.5
bits = 12
metric_prefix = 1000

# scale_factor = 64
# bias = 0

def int_to_hex(int_in, nibbles_per_int):
    
    line = ""

    el_hex_str = str(hex(int_in))[2:]
    if (len(el_hex_str) < nibbles_per_int):
        el_hex_str = ("0" * (nibbles_per_int - len(el_hex_str))) + el_hex_str
    
    line = line + el_hex_str + "\n"

    return line

lines = []
with open("../matlab/new_lerp_ch3.csv", 'r') as file:
    # Iterate over each line in the file
    for line in file:
        # Strip leading/trailing whitespace and append the line to the list
        # voltage = (float(line)*scale_factor) + bias

        # voltage = float(line)
        # adc_code = (voltage * (2**bits)) // (adc_ref * metric_prefix)
        adc_code = float(line) 
        lines.append(int_to_hex(int(adc_code),3))


with open("../top/new_lerp_ch3.hex", 'w') as file:
    file.writelines(lines)