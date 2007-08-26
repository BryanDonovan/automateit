module AutomateIt
  class AddressManager
    # == AddressManager::Linux
    #
    # A Linux-specific driver for the AddressManager provides complete support
    # for querying, adding and removing addresses on platforms that feature
    # Linux-like tools.
    class Linux < Plugin::Driver
      include ResolvHelpers

      depends_on :programs => %w(ifconfig ip arping)

      def suitability(method, *args) # :nodoc:
        return available? ? 2 : 0
      end

      # See AddressManager#has?
      def has?(opts)
        raise ArgumentError.new(":device or :address must be specified") unless opts[:device] or opts[:address]
        result = true
        result &= interfaces.include?(opts[:device]) if opts[:device] and not opts[:label]
        result &= interfaces.include?(opts[:device]+":"+opts[:label]) if opts[:device] and opts[:label]
        result &= addresses.include?(opts[:address]) if opts[:address]
        return result
      end

      # See AddressManager#add
      def add(opts)
        announcements = opts[:announcements].to_i || AutomateIt::AddressManager::DEFAULT_ANNOUNCEMENTS
        raise SecurityEror.new("you must be root") unless Process.euid.zero?
        raise ArgumentError.new(":device and :address must be specified") unless opts[:device] and opts[:address]
        return false if has?(opts)
        #run(%{ip address add #{ip}/#{mask} brd + dev #{device} label #{device}:#{label}})
        if interpreter.sh(_add_or_remove_command(:add, opts))
          #run(%{arping -q -c 3 -A -I #{device} #{ip} &})
          return interpreter.sh("arping -q -c #{announcements} -A -I #{opts[:device]} #{opts[:address]}")
        else
          return false
        end
      end

      # See AddressManager#remove
      def remove(opts)
        return false unless has?(opts)
        raise SecurityEror.new("you must be root") unless Process.euid.zero?
        raise ArgumentError.new(":device and :address must be specified") unless opts[:device] and opts[:address]
        return interpreter.sh(_add_or_remove_command(:remove, opts))
      end

      def _add_or_remove_command(action, opts)
        _raise_unless_available
        case action.to_sym
        when :add
          # Accept
        when :remove
          # Rename
          action = :del
        else
          raise ArgumentError.new("action must be :add or :remove")
        end

        # Accept common alternative names
        opts[:mask] ||= opts[:netmask] if opts[:netmask]
        opts[:alias] ||= opts[:alias] if opts[:alias]
        opts[:device] ||= opts[:interface] if opts[:interface]

        # ip address add 10.0.0.123/24 brd + dev eth0 label eth0:foo
        ipcmd = "ip address #{action} #{opts[:address]}"
        ipcmd += "/#{opts[:mask]}" if opts[:mask]
        ipcmd += " brd + dev #{opts[:device]}"
        ipcmd += " label #{opts[:device]}:#{opts[:label]}" if opts[:label]
        return ipcmd
      end
      private :_add_or_remove_command

      # See AddressManager#interfaces
      def interfaces()
        _raise_unless_available
        return `ifconfig`.scan(/^(\w+?(?::\w+)?)\b\s+Link/).flatten
      end

      # See AddressManager#addresses
      def addresses()
        _raise_unless_available
        return `ifconfig`.scan(/inet6? addr:\s*(.+?)\s+/).flatten
      end
    end
  end
end