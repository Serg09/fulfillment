module RemoteFileProvider
  class Nil
    def send_file(file, remote_file_name, directory = nil)
    end

    def get_and_delete_files(directory = nil)
      []
    end
  end
end
