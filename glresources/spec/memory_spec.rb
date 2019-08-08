require 'spec_helper'
require 'libraries/memory'

describe_inspec_resource 'memory' do
  context 'with no content' do
    environment do
      file('free_m.txt').returns(exist?: false, content: '')
      file('free-m.txt').returns(exist?: false, content: '')
      file('bogusfile.notfound').returns(exist?: false, content: '')
    end

    it 'should not find any files' do
      expect(resource.exists?).to eq false
    end
  end

  context 'with free_m.txt' do
    environment do
      file('free_m.txt').returns(exist?: true, content: File.read('spec/fixtures/free_m.txt'))
    end

    it 'should find the memory file' do
      expect(resource.exists?).to eq true
    end

    it 'should find swap space info' do
      swap_data = { "available" => nil, "buff/cache" => nil, "free" => 100, "shared" => nil, "total" => 100, "used" => 0 }
      expect(resource.swap).to eq swap_data
    end

    it 'should find mem info' do
      mem_data = { "available" => 5114, "buff/cache" => 4889, "buffers" => 0, "cached" => 4889, "free" => 681, "shared" => 160, "total" => 7478, "used" => 1906 }
      expect(resource.mem).to eq mem_data
    end

    it 'should get free swap value' do
      expect(resource.free_swap).to eq 100
    end

    it 'should get total swap value' do
      expect(resource.free_swap).to eq 100
    end

    it 'should get used memory value' do
      expect(resource.used_mem).to eq 1906
    end

    it 'should get buffers_mem' do
      expect(resource.buffers_mem).to eq 0
    end

    it 'should get cached_mem' do
      expect(resource.cached_mem).to eq 4889
    end

    it 'should get available_mem' do
      expect(resource.available_mem).to eq 5114
    end

    it 'should get total_mem' do
      expect(resource.total_mem).to eq 7478
    end
  end

  context 'with free-m.txt' do
    environment do
      file('free_m.txt').returns(exist?: false, content: '')
      file('free-m.txt').returns(exist?: true, content: File.read('spec/fixtures/free-m.txt'))
    end

    it 'should find the memory file' do
      expect(resource.exists?).to eq true
    end

    # need to think of a better way to handle this
    # this test is duplicated because the free-m.txt does not include an
    # available memory value so it has to calculate it base on other values
    it 'should get available_mem' do
      # total   free    buffers   cached    available
      # 32109 - 13505 + 275     + 2561    = 21440
      expect(resource.available_mem).to eq 21440
    end
  end
end
