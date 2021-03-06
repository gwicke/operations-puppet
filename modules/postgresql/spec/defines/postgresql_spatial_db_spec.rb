require 'spec_helper'

describe 'postgresql::spatialdb', :type => :define do
    let(:title) { 'somedb' }
    let(:params) { {
        :ensure => 'present',
        }
    }
    context 'with ensure present' do
        it { should contain_exec('create_db-somedb') }
        it { should contain_exec('create_plpgsql_lang-somedb') }
        it { should contain_exec('create_postgis-somedb') }
        it do
            pending 'not really needed yet'
            should contain_exec('create_spatial_ref_sys-somedb')
        end
        it do
            pending 'not really needed yet'
            should contain_exec('create_postgis_comments-somedb')
        end
    end
end

describe 'postgresql::spatialdb', :type => :define do
    let(:title) { 'somedb' }
    let(:params) { {
        :ensure => 'absent',
        }
    }
    context 'with ensure absent' do
        it { should contain_exec('drop_db-somedb') }
        it { should contain_exec('drop_plpgsql_lang-somedb') }
        it do
            pending 'not really needed yet'
            should contain_exec('drop_spatial_ref_sys-somedb')
        end
        it do
            pending 'not really needed yet'
            should contain_exec('drop_postgis_comments-somedb')
        end
    end
end
