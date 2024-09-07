adc_ref = 2.5
bits = 12
metric_prefix = 1000

scale_factor = 24
bias = 1250

lines = []
with open("../samples/wornDataLerp.txt", 'r') as file:
    # Iterate over each line in the file
    for line in file:
        # Strip leading/trailing whitespace and append the line to the list
        voltage = (float(line)*scale_factor) + bias
        adc_code = (voltage * (2**bits)) // (adc_ref * metric_prefix)
        lines.append(str(hex(int(adc_code)))[2:] + "\n")


with open("../test/samples/wornDataLerp.hex", 'w') as file:
    file.writelines(lines)