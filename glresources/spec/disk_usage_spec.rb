require 'spec_helper'
require 'libraries/disk_usage'

describe_inspec_resource 'disk_usage' do
  context 'with no content' do
    environment do
      file('df_h.txt').returns(exist?: false, content: '')
    end

    it 'should not find root fs' do
      expect(resource.exists?('/')).to eq false
    end

    it 'should not return a mount' do
      expect(resource.mount('/').exists?).to eq false
    end
  end

  context 'with good content' do
    environment do
      file('df_h.txt').returns(exist?: true, content: File.read('spec/fixtures/df_h.txt'))
    end

    let(:rootfs) { resource.mount('/') }
    let(:nofs) { resource.mount('nofs') }

    it 'should return a standardize size' do
      expect(resource.to_filesize('250M')).to eq '250.0M'
      expect(resource.to_filesize(262144000)).to eq '250.0M'
    end

    it 'should find root fs' do
      expect(rootfs.exists?).to eq true
    end

    it 'should not find non-existant fs' do
      expect(nofs.exists?).to eq false
    end

    it 'should not return size for non-existant fs' do
      expect(nofs.size).to eq nil
    end

    it 'should return a mount' do
      expect(rootfs).to_not eq nil
    end

    it 'should have a size' do
      expect(rootfs.size).to eq "10035.2M"
    end
  end
end
