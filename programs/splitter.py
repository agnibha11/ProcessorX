#====================================================
# Project     : RV32IM 5 Stage Pipelined Processor
# Author      : Agnibha Sarkar
#
# Revision    : v1.0
# First Updated: 07-07-2026
#====================================================
import argparse
import sys

def split_to_little_endian(input_file, output_file):
    try:
        with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
            for line_num, line in enumerate(infile, 1):
                # Clean up whitespace and remove 0x prefixes if present
                clean_line = line.strip().replace("0x", "").replace("0X", "")
                
                # Skip empty lines
                if not clean_line:
                    continue
                
                # Verify that the line contains exactly a 4-byte (8 hex character) string
                if len(clean_line) != 8:
                    print(f"Warning: Skipping line {line_num}. Expected 8 hex characters, got {len(clean_line)} ('{line.strip()}')", file=sys.stderr)
                    continue
                
                # Extract bytes in Little Endian order (LSB first, MSB last)
                # Example: "00a00093" 
                lsb_byte0 = clean_line[6:8]  # '93'
                byte1     = clean_line[4:6]  # '00'
                byte2     = clean_line[2:4]  # 'a0'
                msb_byte3 = clean_line[0:2]  # '00'
                
                # Write each byte on its own separate line
                outfile.write(f"{lsb_byte0}\n")
                outfile.write(f"{byte1}\n")
                outfile.write(f"{byte2}\n")
                outfile.write(f"{msb_byte3}\n")
                
        print(f"Successfully converted '{input_file}' to Little Endian byte format in '{output_file}'")
        
    except FileNotFoundError:
        print(f"Error: The file '{input_file}' could not be found.", file=sys.stderr)
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(
        description="Convert a 4-byte hex instruction file into a 1-byte-per-line Little Endian file for Verilog readmemh."
    )
    parser.add_argument("input_file", help="Path to the input .txt file containing 4-byte hex instructions.")
    parser.add_argument("output_file", help="Path to the output .dat destination file.")
    
    args = parser.parse_args()
    split_to_little_endian(args.input_file, args.output_file)

if __name__ == "__main__":
    main()