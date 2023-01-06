import json
import os
import os.path

replacements = {
    "PrimaryFirearm:BP_SVD_63": {
					"Type": "PrimaryFirearm",
					"Item": "PrimaryFirearm:BP_AK74",
					"Children": [
						{
							"Item": "Magazine:BP_AK545_Magazine",
							"Well": "MagWell_AK545"
						},
						{
							"Item": "Sight:BP_1P78_Kashtan_Scope",
							"Comp": "FirearmMeshComponent0"
						}
					]
				},
    "Head:BP_Rebel_Head_01": {
					"Type": "Head",
					"Item": "Head:BP_Rebel_Head_02"
				}
}

def process_data(data):
    item_name = data.get('Item', None)
    if item_name in replacements:
        return replacements[item_name]
    
    raw_data = data.get('Data', [])
    if raw_data:
        new_items = []
        for item in raw_data:
            new_items.append(process_data(item))
        
        data['Data'] = new_items

    return data

def process(data):
    new_items = []
    for item in data['Data']:
        new_items.append(process_data(item))
    
    data['Data'] = new_items

base_path = r'GroundBranch\Content\GroundBranch\AI\Loadouts\Processing'

kit_files = []

for (root, dirs, files) in os.walk(base_path):
    for file in files:
        if file.endswith(".kit"):
            kit_path = os.path.join(root, file)
            with open(os.path.join(root, file), 'rb') as input_file:
                data = json.load(input_file)

            print(f'Processing {file} ...')
            process(data)

            with open(os.path.join(root, file), 'wt') as output_file:
                json.dump(data, output_file, indent='\t')
