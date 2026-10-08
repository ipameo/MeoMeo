import json

cfg = {
    "EspMaster": True,
    "EspBox": True,
    "EspLine": True,
    "server_esp": False,
    "token": "91d4b7466c8a1ca345c105d370784342",
    "system_active": True
}
json_str = json.dumps(cfg, indent=2).replace(" ", "")
print("json_str:")
print(json_str)
print("has server_esp:false?", '"server_esp":false' in json_str)
print("has EspMaster:true?", '"EspMaster":true' in json_str)
