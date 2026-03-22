import yaml
import os
from pathlib import Path
from types import SimpleNamespace
class ConfigurationError(Exception):
    pass

import sys
if getattr(sys, 'frozen', False):
    ROOT_DIR = Path(sys.executable).parent
else:
    ROOT_DIR = Path(__file__).parent.parent 

class Settings:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(Settings, cls).__new__(cls)
            cls._instance._init()
        return cls._instance

    def _init(self):
        self._cache = {}

    def load(self, module: str) -> SimpleNamespace:
        """
        Loads configuration for a specific module (e.g. 'face', 'finger').
        Looks for 'master.yaml' in the module directory.
        """
        if module in self._cache: 
            return self._cache[module]
        
        module_map = {
            "network": "blockchain", # backend.py identifies it as 'network', file is in 'blockchain/'
        }
        directory = module_map.get(module, module)
        
        path = ROOT_DIR / directory / "master.yaml"
        
        if not path.exists():
            raise ConfigurationError(f"Configuration not found for module '{module}' at {path}")

        try:
            with open(path, "r") as f:
                raw_cfg = yaml.safe_load(f) or {}
                
            resolved_cfg = self._resolve_paths(raw_cfg)
            
            namespace_cfg = self._to_namespace(resolved_cfg)
            self._cache[module] = namespace_cfg
            return namespace_cfg
            
        except Exception as e:
            raise ConfigurationError(f"Failed to load config for '{module}': {e}")

    def _resolve_paths(self, cfg):
        """Recursively resolves paths relative to ROOT_DIR."""
        if isinstance(cfg, dict):
            new_cfg = {}
            for k, v in cfg.items():
                if isinstance(v, (dict, list)):
                    new_cfg[k] = self._resolve_paths(v)
                elif isinstance(k, str) and (k.endswith("_path") or k.endswith("_file") or k == "enrollments" or k == "keys"):
                    if v and isinstance(v, str):
                        path_obj = Path(v)
                        if not path_obj.is_absolute():
                            new_cfg[k] = str((ROOT_DIR / v).resolve())
                        else:
                            new_cfg[k] = v
                    else:
                        new_cfg[k] = v
                else:
                    new_cfg[k] = v
            return new_cfg
        elif isinstance(cfg, list):
            return [self._resolve_paths(item) for item in cfg]
        else:
            return cfg

    def _to_namespace(self, d):
        """Recursively converts dict to SimpleNamespace."""
        if isinstance(d, dict):
            return SimpleNamespace(**{k: self._to_namespace(v) for k, v in d.items()})
        elif isinstance(d, list):
            return [self._to_namespace(i) for i in d]
        else:
            return d

sys_config = Settings()
