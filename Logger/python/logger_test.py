
from tag.io.log import Logger
from tag.utils.debug import data_dumper

def print_object(obj,comment="Output"):
    obj_string = data_dumper(obj)
    print(comment +":\n" + obj_string)




# Retrieve version number
print("Version: ")
print(Logger.__version__)


# Create Logger object
logger_opts = {
    'filename': 'foo.txt',
    'max_size': 2500000,
}
logger = Logger(**logger_opts)
print_object(logger, "Logger object contains")

# Custom Module created ..
# I created a module function to give me the
# behavior of perls Data::Dumper. See tag.utils.debug.data_dumpoer
#
