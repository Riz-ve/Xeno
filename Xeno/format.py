import regex as re # Much faster than normal re
import sys, os, time

def main():
    if len(sys.argv) < 2:
        print("Usage: format.py <file>")
        time.sleep(3)
        exit(-1)

    file_name = sys.argv[1]

    if not os.path.isfile(file_name):
        print(f"{file_name} was not found")
        time.sleep(3)
        exit(-1)
    
    with open(file_name, 'r') as file:
        contents = file.read()

        contents = re.sub(r'"[^"]*"', lambda match: match.group(0).replace('\n', ' '), contents)
        contents = re.sub(r'\n+', ' ', contents)
        contents = re.sub(r'(\S)\s{2,}(\S)', r'\1 \2', contents)
        contents = contents.replace('"', '\\"')
    
    with open('./formatted.txt', 'w') as formatted:
        formatted.write(f'"{contents}"')

if __name__ == "__main__":
    main()