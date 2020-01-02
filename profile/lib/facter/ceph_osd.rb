require 'json'

def parse_output(output)
  osd_array = []
  parsed_output = JSON.parse(output)['nodes']
  parsed_output.each do |node|
    next unless node['name'] == Facter.value(:hostname)
    node['children'].each do |osd|
      osd_array << "ceph-osd.#{osd}"
    end
  end
  osd_array
end

Facter.add('ceph_osds') do
  confine hostname: /storage|object-ceph/

  setcode do
    output = Facter::Core::Execution.execute('ceph osd tree -f json',
                                             timeout: 30)
    osds = parse_output(output)
    osds
  end
end