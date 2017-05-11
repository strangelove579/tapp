#!/usr/bin/python

# exceptions_ex.py
#
# John Achee, 3/26/17
#
#  Just a simple little script to test the exception handling
#  info I have learned so far
#
#

# Python Exception handling example script written by a newbie...

#  Observations so far:

#  As with any programming language, python will automatically raise exceptions
#  as Exception objects, or objects for classes that sub-class the Exceptions
#  class.

#  Custom exceptions allow you to handle problem scenarios that relate to the
#  logical operation of your program. Python will not care about your app
#  logic, so you must create and throw your own exceptions so that it will! These
#  user-defined exceptions must sub-class Exception or one of its sub-classes
#  such as ValueError, ZeroDivisionError, TypeError, etc

#  Python vs. Perl
#  Python exception handling is more strictly OO and
#  therefore a bit more structured than perl. Where in perl you would often
#  simply check the return value of a subroutine call or handle a die string
#  thrown from an eval, matching the string with perhaps a regex.
#  That said, Perl CPAN modules do exist which do provide an OO exception
#  handling implementation, such as Class::Exception. However, usage of said
#  modules are optional (and rare)


#------------------------------------------------------------------------------
#  User-Defined Exception Classes
#------------------------------------------------------------------------------
#
# These classes define my simple custom exceptions SpamError and EggsError
# Custom exceptions MUST subclass the class Exception or any of its
# existing subclasses (eg: ValueError)
# The common practice is to:
#   Create a class named Error
#   This class should subclass Exception, ie: Error(Exception)
#   Then define your custom exceptions by subclassing Error()
#   Your custom class can also derive from a subclass of Exception,
#   but dont forget to make a class to 'super'.__init(...) to properly
#   handle this type of exception
#
# The simplest way to throw an error is to raise it by creating an
# exception object and passing in a simple string, ie:
#
#  raise Exception("spam")

# the sys module can be used to get the type of built-in exception thrown
import sys


class MyError(Exception):
    """ Base class for user-defined exceptions """
    pass  # A non-op, like 'undef' in perl

class SpamError(MyError):
    """ Spam Error """
    pass

class EggsError(MyError):
    """ Eggs Error """
    pass




print ("1. Raise my custom exception \"SpamError\"")

try:
    raise SpamError("spam error string here!")
except SpamError as fe:
    # For fun, we use the format method of the string class below. it is similar to printf
    # This would be ugly in production code
    print ("\t-->{0}: {1}".format("SpamError",str(fe)))
    print ()
except:
    print ("\t-->OtherError: Not a SpamError()")
    print ()
else:
    print ("\t-->I R SUCCESS :(")
    print ()





print ("2. Raise custom SpamError(), with no matching SpamError() handler. Instead, fail over to catch-all handler!")

try:
    raise SpamError("another spam!")
except EggsError as be:
    print ("\t-->EggsError: " + str(be))
    print ()
except:  # Catch-all handler
    print ("\t-->Error: got something else!")
    print ()
else:
    print ("\t-->I R SUCCESS :(")
    print ()







print ("3. Raise custom SpamError(), with no matching SpamError() handler. And we dont have a catchall handler!")

try:
    try:
        raise SpamError("This SpamError would kill the script! Its not handled and there is no catch-all (this is bad programming!)")
    except EggsError as be:
        print ("\t-->Error: " + str(be))
    else:
        print ("\t-->No Errors! :)")
except:
    print("\t-->Error: The inner exception killed the script... but I saved it!")
finally:
    print("\t   ...and finally...Im a finally block and I always print!")
    print ()





print ("4. Here we perform an operation that should throw a ValueError which is a python system error")
print ("   We handle this by creating a handler for ValueError()")


try:
    myString = "abc"
    myNotGonnaWork = int(myString)
except ValueError as ve:
    print ("\t-->ValueError: " + str(ve))
    print ()
except:
    print ("\t-->Error: Some error happened by it wasn't a ValueError()")
    print ()


print ("5. Unhandled system errors")
print ("   Catch-all exception handlers should tell us the name of the ")
print ("   exception, this is done using the 'sys' module")


try:
    myString = "abc"
    myNotGonnaWork = int(myString)
except:
    print ("\t-->Unexpected Exception: ", sys.exc_info()[0])
    print ("\t   ... Normally we would re-raise with the single word 'raise' here")
    print ()



print ("6. Class Exception Properties and methods")
print ("   The below example is taken from Python documentation")
print ("   It demonstrates the various properties and methods that are available for Exceptions")


try:
    raise Exception('spam', 'eggs')
except Exception as inst:
    print("\t", type(inst))    # the exception instance
    print("\t", inst.args)     # arguments stored in .args
    print("\t", inst)          # __str__ allows args to be printed directly,
                               # but may be overridden in exception subclasses
    x, y = inst.args           # unpack args
    print("\t", 'x =', x)
    print("\t", 'y =', y)





print ("7. Most basic custom error, created by creating an exception object with a string arg")

try:
    raise Exception("My simple exception occurred!")
except Exception as e:
    print ("\t--->Error: {0}".format(e))
