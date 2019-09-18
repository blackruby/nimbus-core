class UpdatesController < ApplicationController
  def index
    @assets_stylesheets = %w(updates)
    @assets_javascripts = %w(updates)

    #@updates = Dir.glob('data/_nim_updates/*').map {|u| u.split('/')[-1]}.sort.reverse.map{|u| e = u.split(' '); e[0].split('-').reverse.join('-') + ' ' + e[1]}
    #@updates = Dir.glob('data/_nim_updates/*').map {|u| u.split('/')[-1]}.sort.reverse
    @updates = Dir['data/_nim_updates/*'].sort_by{|f| File.mtime(f)}.map{|f| f.split('/')[-1]}.reverse
  end

  def get_update
    render json: ERB.new(File.read("data/_nim_updates/#{params[:file]}")).result(binding).to_json
  end
end