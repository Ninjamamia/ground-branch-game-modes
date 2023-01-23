import json
import os
import os.path

def convert_from_10(data):
    new_data = {'Ver': 11, 'Data': []}
    for item in data['Data']:
        if len(item['Data']) > 0:
            new_data['Data'].append(item)
    
    return new_data

base_path = r'GroundBranch\Content\GroundBranch\AI\Loadouts'

kit_files = []

for (root, dirs, files) in os.walk(base_path):
    for file in files:
        if file.endswith(".kit"):
            kit_path = os.path.join(root, file)
            with open(os.path.join(root, file), 'rb') as input_file:
                touched = False
                data = json.load(input_file)

            if data['Ver'] == 10:
                touched = True
                print(f'Converting {file} ...')
                data = convert_from_10(data)

            if touched:
                with open(os.path.join(root, file), 'wt') as output_file:
                    json.dump(data, output_file, indent='\t')

