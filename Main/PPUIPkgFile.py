"""
    Experimental tool to extract/import ppuipkg files

    usage: PPUIPkgFile.py -[h|x|i|l] path/to/file.ppkui
    Examples:

    Extract from ovldata/Content0/Main/Test.ppuipkg into ./Test/
    # python PPUIPkgFile.py -x ovldata/Content0/Main/Test.ppuipkg

    Create ovldata/Content0/Main/Test.ppuipkg using the files in
    the ./Test/ folder
    # python PPUIPkgFile.py -i ovldata/Content0/Main/Test.ppuipkg

    # Note, this tool doesn't account for the png userinterfaceicondata
    entries, do not use this script to regenerate vanilla ppuipkg files
    for now.

"""

import os, io
import argparse
import xml.etree.ElementTree as ET 


class PPUIPkgFileInfo():

    def __init__(self, path, content):
        self.name = path
        self.content = content

    def read(self, count=None):
        return self.content

    def close(self):
        pass

    def __str__(self):
        return f"<PPUIPkgFileInfo name='{self.name}' file_size={len(self.content)}>"


class PPUIPkgFile():

    def __init__(self, path, mode='r'):
        self.basic = 'Mod_ModMenu/Main'
        self.mode  = mode
        self.files = []
        self.icons = []
        self.path  = path
        if mode != 'w':
            self._read_file()

    def _read_file(self, path=None):
        if not path:
            path = self.path

        tree = ET.parse(path)
        root = tree.getroot()
        files = root.find('files') 
        for file in files:
            name = file[0].text
            content = b"".join([int(o).to_bytes(1, 'big', signed =True) for o in file[1].text.split()]) 
            self.files.append(PPUIPkgFileInfo(name, content))


    def __enter__(self):
        return self

    def __exit__(self, exception_type, exception_value, exception_traceback):
        #Exception handling here
        self.close()
        pass

    def infolist(self):
        return self.files

    def namelist(self):
        return [o.name for o in self.files]

    def getinfo(self, path):
        return [o for o in self.files if o.name == path][0]
        pass

    def is_ppuipkgfile(self, path):
        pass

    def printdir(self):
        pass

    def remove(self, member):
        self.files.remove(member)

    def extract(self, member, path=None):
        self._write_file(os.path.join(path, '.', member.name), member.content)

    def extractall(self, path=None):
        for f in self.infolist():
            self.extract(f, path)

    def _write_file(self, path, content, overwrite = True):
        """ write  content to a file
        :param path: file path
        :param content: the content to write
        :return: content of the file
        """ 
        if overwrite == False and os.path.exists(path):
            return
        try:
            os.makedirs(os.path.dirname(path))
        except:
            pass
        with open(path, 'wb') as f:
            #print(f"Creating {path}")
            content = f.write(content)
            f.close
            return

    def open(self, path, mode='r'):
        if path in self.namelist():
            return self.getinfo(path)
        else:
            # make new
            pass

    def write(self, name, path):
        name = name.replace("\\","/")
        content = open(os.path.join(path, name), 'rb').read()
        self.files.append(PPUIPkgFileInfo(name, content))

    def close(self):
        if self.mode == 'r':
            # just ignore the close
            pass
        else:
            # write the contents into the file
            self._write_files(self.path)

    def importall(self, path=None):
        print(f"Importing from {path}")
        ppkfiles = self._get_file_list(path)
        for name in ppkfiles:
            self.write(name, path)

    def _get_file_list(self, path):
        """ Gets a list of files from a folder """
        files = [os.path.relpath(val, path) for sublist in [[os.path.join(i[0], j) for j in i[2]] for i in os.walk(path)] for val in sublist]
        return files

    def _write_files(self, name, path=None):
        root = ET.Element('PPUIPKGRoot', 
          {
            'file_count': str(len(self.files)), 
            'icondata_count': '0', 
            'game' : "Planet Coaster 2" 
          }
        )
        basic_path = ET.SubElement(root, 'basic_path')
        basic_path.text = self.basic

        files = ET.SubElement(root, 'files')

        for fileInfo in self.files:
            file_size = len(fileInfo.content)
            file = ET.SubElement(files, 'ppuipkgfile', {'file_size' : str(file_size)})
            filename = ET.SubElement(file, 'file_name')
            filename.text = fileInfo.name.replace("\\","/")
            filedata = ET.SubElement(file, 'file_content')
            filedata.text = " ".join(  [str(byte) for byte in bytearray(fileInfo.content)] )

        types = ET.SubElement(root, 'types')
        f = open(name, 'wb')
        f.write( ET.tostring(root) )
        f.close()


if __name__ == "__main__": 

    import getopt
    import sys

    # Get the arguments from the command-line except the filename
    argv = sys.argv[1:]
    sum = 0

    try:
        # Define the getopt parameters
        # TODO: add and arg to allow overriding the default input/output path
        opts, args = getopt.getopt(argv, 'hxil', ['path'])

        # Check if the options' length is 2 (can be enhanced)
        if len(args) > 1 or len(opts) == 0 and len(opts) > 2:
          print ('usage: PPUIPkgFile.py -[h|x|i|l] path/to/file.ppkui')
        else:
          # Iterate the options and get the corresponding values
          for opt, arg in opts:
            match (opt):
                case '-h':
                    print("PPUIPkgFile tool - Extract and create ppuipkg files")
                    print("-h         This help screen.")
                    print("-l  file   List the contents of a ppkuipkg file.")
                    print("-x  file   Extract the contents of a ppuipkg file into a folder (with the name of the file without extension).")
                    print("-i  file   Imports the contents of a folder into a ppuipkg file (from a folder with name of the file without extension).")
                    sys.exit(1)
                case '-l':
                    print("Listing file contents")
                    with PPUIPkgFile(args[0]) as pkg:
                        print(pkg.namelist())
                    sys.exit(1)

                case '-x':
                    print("Extracting all files")
                    with PPUIPkgFile(args[0]) as pkg:
                        # Extract to a folder name with the same name as the file
                        path = os.path.splitext(os.path.basename(args[0]))[0]
                        pkg.extractall(path)
                    sys.exit(1)

                case '-i':
                    print("Importing all files")
                    with PPUIPkgFile(args[0], 'w') as pkg:
                        # Import from a folder name with the same name as the file
                        path = os.path.splitext(os.path.basename(args[0]))[0]
                        pkg.importall(path)
                    sys.exit(1)


    except getopt.GetoptError:
        # Print something useful
        print ('usage: PPUIPkgFile.py -[h|x|i|l] path/to/file.ppkui')
        sys.exit(2)



"""

    Expected usage

    # Open a file for reading/extracting
    with PPUIPkgFile('CustomUITest1.ppuipkg') as pkg:

        # Print a list of the file handlers
        print(pkg.infolist())

        # Print a list of the file names
        print(pkg.namelist())

        # Print a handler by file name
        print(pkg.getinfo(pkg.namelist()[-1]))

        # Open an internal file for reading
        file = pkg.open(pkg.namelist()[-1], mode = 'r')
        print(file.read()) 
        file.close()

        # Extract all files to a folder
        pkg.extractall(path='./ExtractHere')

    # Open a file for creating/adding
    with PPUIPkgFile('NewFile.ppuipkg', mode='w') as pkg:

        # add a file:
        pkg.write('./ExtractHere/UIGameface/CustomUITest2.html')

        # Import all files from a folder
        pkg.importall(path='./ExtractHere')


    # Open a file for appending/adding/removing:
    # NOT IMPLEMENTED
    with PPUIPkgFile('NewFile.ppuipkg', mode='a') as pkg:

        # Print a list of the file names
        print(pkg.namelist())

        # add a file from a folder
        pkg.write('./ExtractHere/UIGameface/CustomUITest1.html')

        # remove a file
        pkg.remove('./ExtractHere/UIGameface/CustomUITest2.html')

"""
