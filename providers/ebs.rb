#
# Cookbook Name:: volumes
# Provider:: ebs
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

action :create do
  ohai 'reload_block_devices' do
    plugin 'linux::block_device'
    action :nothing
  end

  ebs_volumes = new_resource.ebs_volumes
  ebs_volumes.each do |ebs_volume|
    aws_ebs_volume "#{ebs_volume['device'].gsub(/^\//, '').gsub('/', '-')}_as_#{ebs_volume['size']}gb_vol" do
      aws_access_key        new_resource.aws_access_key
      aws_secret_access_key new_resource.aws_secret_access_key
      size                  ebs_volume['size'].to_i
      availability_zone     ebs_volume['zone']
      device                ebs_volume['device']
      description           "#{node['fqdn']}_#{ebs_volume['device']}"
      timeout               new_resource.timeout
      action [:create, :attach]
      notifies :reload, resources(:ohai => 'reload_block_devices'), :immediately
    end
  end
  
  new_resource.updated_by_last_action(true)
end
