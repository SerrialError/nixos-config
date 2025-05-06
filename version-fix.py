import pros.common.utils

def patched_get_version():
    return "3.5.5"
 
pros.common.utils.get_version = patched_get_version 