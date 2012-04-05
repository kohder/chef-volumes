#
# Cookbook Name:: volumes
# Recipe:: default
#
# Copyright 2012, Rob Lewis <rob@kohder.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

all_volume_plan_names = data_bag('volume_plans')
node_volume_plans = Array(node['volumes']['plans'])
node_volume_plans.each do |node_volume_plan_name|
  if !all_volume_plan_names.include?(node_volume_plan_name)
    Chef::Log.error("No data bag entry for volume plan\"#{node_volume_plan_name}\"")
    next
  end
  volume_plan = data_bag_item('volume_plans', node_volume_plan_name)

  Chef::Log.info("Applying volume plan: #{node_volume_plan_name}")

  unless volume_plan['ebs_volumes'].nil?
    node.run_state['volumes'] ||= {}
    access_key = node.run_state['volumes']['aws_access_key'] || node['volumes']['aws_access_key']
    secret_key = node.run_state['volumes']['aws_secret_access_key'] || node['volumes']['aws_secret_access_key']

    if access_key.nil? || access_key.empty? || secret_key.nil? || secret_key.empty?
      raise 'The Volumes cookbook cannot create EBS volumes without having AWS keys set.'
    end

    volume_plan['ebs_volumes'].each do |ebs_volume|
      aws_ebs_volume "Create #{ebs_volume['size']}GB EBS volume for #{node['fqdn']} as #{ebs_volume['device']}" do
        aws_access_key        access_key
        aws_secret_access_key secret_key
        size                  ebs_volume['size'].to_i
        availability_zone     ebs_volume['zone']
        device                ebs_volume['device']
        description           "#{node['fqdn']}_#{ebs_volume['device']}"
        timeout               5*60  # 5 mins
        action [:create, :attach]
      end
    end
  end

  unless volume_plan['lvm_volume_groups'].nil?
    volume_plan['lvm_volume_groups'].each do |lvm_volume_group|
      lvm_volume_group_name = lvm_volume_group['name']
      physical_volumes = Array(lvm_volume_group['physical_volumes'])
      unless physical_volumes.empty?

        lvm_pv "pvcreate-#{lvm_volume_group_name}" do
          devices physical_volumes
          action :create
        end

        lvm_vg "vgcreate-#{lvm_volume_group_name}" do
          devices physical_volumes
          volume_group_name lvm_volume_group_name
          action :create
        end

        logical_volumes = Array(lvm_volume_group['logical_volumes'])
        logical_volumes.each do |logical_volume|
          filesystem_type = logical_volume['filesystem'] || 'xfs'
          device_name = "/dev/mapper/#{lvm_volume_group_name}-#{logical_volume['name']}"
          device_key = device_name.gsub('/', '_')

          execute "mkfs-#{device_key}" do
            command "yes | mkfs -t #{filesystem_type} #{logical_volume['filesystem_opts']} #{device_name}"
            action :nothing
          end

          lvm_lv "lvcreate-#{device_key}" do
            volume_group_name lvm_volume_group_name
            logical_volume_name logical_volume['name']
            stripes logical_volume['stripes']
            stripe_size logical_volume['stripe_size']
            logical_extents logical_volume['logical_extents']
            action :create
            notifies :run, resources(:execute => "mkfs-#{device_key}"), :immediately
          end

          mount_point = logical_volume['mount']
          if mount_point
            directory mount_point do
              mode '0000'
              action :create
              not_if { ::File.exists?(mount_point) }
            end

            mount mount_point do
              device device_name
              fstype filesystem_type
              options logical_volume['mount_opts']
              action [:mount, :enable]
            end

            directory mount_point do
              mode '0777'
              action :create
            end
          end
        end
      end
    end
  end
end
