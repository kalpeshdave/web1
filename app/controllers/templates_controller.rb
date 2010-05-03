# Copyright (C) 2009 Pascal Rettig.

class TemplatesController < CmsController # :nodoc: all

  permit 'editor_design_templates'

  layout 'manage' 
  
  helper :page
  helper :application
  
  cms_admin_paths 'options', 
      'Options' => { :controller => 'options' },
      "Design Templates" => { :controller => 'templates' },
      "Site Features" => { :action => 'features' }

   include SiteNodeEngine::Controller
  
  protected
  def expire_site
    DataCache.expire_container('SiteNode')
    DataCache.expire_container('SiteNodeModifier')
    DataCache.expire_container('SiteTemplate')
    DataCache.expire_content()
  end
  
  
  public
  
   # need to include 
   include ActiveTable::Controller   
   active_table :site_templates_table,
                SiteTemplate,
                [ ActiveTable::StringHeader.new('name'),
                  ActiveTable::OptionHeader.new('template_type', :label => 'Type',:options => :type_options),
                  ActiveTable::OrderHeader.new('IF(parent_id,parent_id,id), parent_id, name',:label => 'Parent'),
                  ActiveTable::StringHeader.new('description'),
                  ActiveTable::IconHeader.new('',:width => '15')
                ]
  def type_options; SiteTemplate.template_type_select_options; end

  public
  # List of current templates in the site
  def index
    templates_table(false)
    
    cms_page_path [ "Options" ], "Design Templates" 
    
    render :action => 'index'
  end
  
  def templates_table(render_partial = true)
    @active_table_output = site_templates_table_generate params, :order => 'IF(parent_id,parent_id,id), parent_id, name ', :per_page => 20
  
    render :partial => 'templates_table' if render_partial
  end
  
  # Delete the template given by templates_id
  def delete_template
    @site_template = SiteTemplate.find(params[:path][0])
    @site_template.destroy
    #flash[:notice] = 'Deleted Template: "%s"' / @site_template.name
    templates_table
  end

  def new
    @site_template = SiteTemplate.new(params[:site_template])
    
    cms_page_path ['Options','Design Templates'], 'Create Site Template'
    
    if(request.post?)
      if params[:path][0]
        parent = SiteTemplate.find(params[:path][0])
        @site_template.parent_id = parent.id
        @site_template.domain_file_id = parent.domain_file_id
        @site_template.template_html = parent.template_html
      end
      if @site_template.save
        redirect_to :action => 'edit', :path => @site_template.id
        return
      end
    end
    render :action => 'new'

  end

  def edit
  	session[:templates_view_modifier] = @display_view = params[:view] || session[:templates_view_modifier] || 'advanced'
    @site_template = SiteTemplate.find(params[:path][0])
    if params[:version] && !params[:version].blank?
      flash[:template_version_load] = params[:version]
      redirect_to :action => 'edit',:path => [ params[:path][0] ] 
      return
    end
    
    if flash[:template_version_load]
       @site_template.load_version(flash[:template_version_load])
    end
    cms_page_path ['Options','Design Templates'], [ 'Edit %s',nil,@site_template.name]
    
    if @display_view == 'advanced'
      if @site_template.parent_id
        @tabs = ['options','edit']
        @files = [ ["Template HTML",'template_html','html' ] ] 
      else
        @tabs = ['options','translation','edit'] 
        @files = [ ["Template HTML",'template_html','html' ],
                   [ "Design Styles",'style_design','css' ],
                   [ "Structural Styles", 'style_struct','css' ]]
        @files << [ "HTML Header",'head','html' ]  unless @site_template.template_type == 'mail'
      end
    else
      @tabs = ['options']
      @tabs << 'translation' unless @site_template.parent_id
    end

    @zones=@site_template.site_template_zones
  	@languages = Configuration.languages
	  @options = DefaultsHashObject.new(@site_template.options[:values])
	  
	  @design_styles = @site_template.design_style_details('en')
	  @default_design_styles = Util::CssParser.default_styles(@design_styles);
	  
	  @struct_styles = @site_template.structural_style_details('en')
	  @default_struct_styles = Util::CssParser.default_styles(@struct_styles);
	  
    require_js('edit_area/edit_area_loader')
	  
  end
  
  # Get the default feature data,
  # Handle both publications and hard coded default features
  def default_feature_data
    @feature_type = params[:feature_type]
    
    txt = SiteFeature.default_feature(@feature_type)
  
    render :text => txt;
  end
  
  def refresh_styles
    @site_template = SiteTemplate.find(params[:path][0])
    @site_template.attributes = params[:site_template]
    
    @refresh_type = params[:type]
    if  @refresh_type == 'style_design' 
      @design_styles = @site_template.design_style_details('en')
	    @default_design_styles = Util::CssParser.default_styles(@design_styles);
    else	  
	    @struct_styles = @site_template.structural_style_details('en')
	    @default_struct_styles = Util::CssParser.default_styles(@struct_styles);  
	   end
  end

  def update
    @selected_language = params[:selected_language].to_s
    @site_template = SiteTemplate.find(params[:path][0])
    
    @site_template.set_localization(params[:localize_values],params[:translate],params[:translation])

    @site_template.attributes = params[:site_template]
    @site_template.modified_at= Time.now
    @site_template.modified_by=myself.id

    @parsing_errors = @site_template.update_zones_and_options
    
    if(@site_template.parent_template)
      @site_template.save
    
      parent = @site_template.parent_template
      parent.update_zones_and_options
      parent.save
    else
      @site_template.update_option_values(params[:options])
      @site_template.save
      
      @site_template.update_feature_options
    end

 	  @site_template.update_zone_order!(params[:zone_order].to_s.split(",")) if params[:zone_order]
	
    expire_site
    
    @site_template.site_template_zones.reload
    
    @languages = Configuration.languages
     	    
    @zones = @site_template.site_template_zones
     	  
    @options = DefaultsHashObject.new(@site_template.options[:values])
    
    if @selected_language
      @show_languages = [ @selected_language ]
      @localized_values = {}
      @localized_values[@selected_language] = DefaultsHashObject.new(@site_template.localized_values(@selected_language))
      @localized_options = @site_template.localized_options
    end
         	  
    render :partial => 'update_template'
  end
  
  
  def load_translation
    @site_template = SiteTemplate.find(params[:template_id])
    lang = params[:show_language]
    @show_languages = [ lang ]
    @localized_values = {}
    @localized_values[lang] = DefaultsHashObject.new(@site_template.localized_values(lang))
    @localized_options = @site_template.localized_options
    render :partial => 'language_translation'
  end
  
  def preview
    @site_template_id = params[:path][0]
    @lang = params[:path][1]
    
    @site_template = SiteTemplate.find(@site_template_id)
  
    render :action => 'preview', :layout=> false
  end
  
  def preview_css
    site_template_id = params[:path][0]
    lang = params[:path][1]
    
    headers['Content-Type'] = 'text/css'
     
    render :layout=> false, :text => SiteTemplate.render_template_css(site_template_id,lang)
  end
  
  active_table :features_table, SiteFeature,
              [ :check, 
                hdr(:string,'site_features.name'),
                hdr(:string,'site_features.category'),
                :feature_type,
                hdr(:options,'site_template_id',:options => :site_template_names),
                hdr(:date_range,'site_features.updated_at')                
              ]
              
  private
  
  def site_template_names
    SiteTemplate.select_options
  end
  
  public


  # Features Code
  
  
  def display_features_table(display=true)

    active_table_action('feature') do |act,fids|
      SiteFeature.find(fids).map(&:destroy) if act == 'delete'
    end
    @tbl = features_table_generate params, :order => 'site_features.category,site_features.name', :include => :site_template
    
    render :partial => 'features_table' if display
  end  
  
  def features
    cms_page_path [ "Options", "Design Templates" ], "Site Features"
    display_features_table @tbl
  end
  
  def new_feature
    cms_page_path [ "Options", "Design Templates", "Site Features"], "Create a feature"
    @feature = SiteFeature.new
    @features = ParagraphRenderer.get_editor_features + ParagraphRenderer.get_component_features + ContentPublication.get_publication_features
    
    @feature_options = @features.map  { |feat| [ feat[0],feat[1] ] }

    if request.post? && params[:feature]
      @feature.body = SiteFeature.default_feature(params[:feature][:feature_type])
      redirect_to :action => 'feature',:path => [ @feature.id ] if @feature.update_attributes(params[:feature])
    end
  end
  
  def feature(popup=false,data={})
    @feature = SiteFeature.find_by_id(params[:path][0]) || SiteFeature.new(:feature_type => @paragraph.feature_type.to_s, :name => @paragraph.feature_type.to_s.humanize)
    
    if !@feature.id
      @feature.body = SiteFeature.default_feature(@paragraph.feature_type)
    end

    if params[:copy_feature_id]
      @feature = @feature.clone
      @feature.name += " (Copy)".t
    end
    
    if params[:version] && !params[:version].blank?
      flash[:feature_version_load] = params[:version]
      redirect_to :action => 'feature',:path => [ params[:path][0] ] 
      return
    end
    
    if flash[:feature_version_load]
       @feature.load_version(flash[:feature_version_load])
    end
    
    
    cms_page_path [ "Options", "Design Templates", "Site Features"], [ '"%s" Feature', nil, @feature.name ] 
    
    details = @feature.feature_details
    # [ Human Name, feature_name, Renderer, Publication ]

    # Try to generate automatic feature tag documentation
    begin
      @doc = details[2].document_feature(details[1],data,self,details[3])
    rescue Exception => e
      raise e
      @doc = nil
    end
    
    @default_feature = SiteFeature.default_feature(@feature.feature_type)
    
    @style_details = @feature.style_details
    @reload_url = "?"
    
    
    if @site_template = @feature.site_template
	    @design_styles = @site_template.design_style_details('en')
	    @default_design_styles = Util::CssParser.default_styles(@design_styles)
    else
      @default_design_styles = []
	  end
	  
    
    require_js('edit_area/edit_area_loader')
    require_js('highlight/highlight.pack.js')
    require_css('/javascripts/highlight/styles/default.css')
  end
  
  # Display the feature page in a popup window
  def popup_feature
    @paragraph_index = params[:para_index]
    @paragraph_id = params[:paragraph_id]
    
    @paragraph = PageParagraph.find(@paragraph_id)

    engine = SiteNodeEngine.new(@paragraph.page_revision.revision_container,:display => session[:cms_language], :path => [],:edit => true, :capture => true)

    data ={}
    begin
      @result = engine.run_paragraph(@paragraph,self,myself)
    rescue ParagraphRenderer::CaptureDataException => e
      data = e.data
    end
    
    if params[:version] && !params[:version].blank?
      flash[:feature_version_load] = params[:version]
      redirect_to :action => 'popup_feature',:path => [ params[:path][0] ], :para_index => @paragraph_index, :paragraph_id => @paragraph_id
      return
    end  
    
    feature(true,data)
  
    @reload_url = "?para_index=#{@paragraph_index}&paragraph_id=#{@paragraph_id}&"
    
    render :action=>'feature', :layout => 'manage_window'
  end
  
  def feature_styles
    @feature = SiteFeature.find_by_id(params[:path][0]) || SiteFeature.new
    @feature.attributes = params[:feature]
    
    @style_details = @feature.style_details(true)
  
    if @site_template = @feature.site_template
	    @design_styles = @site_template.design_style_details('en')
	    @default_design_styles = Util::CssParser.default_styles(@design_styles)
    else
      @default_design_styles = []
	  end
	  
  end
  
  def save_feature
    @feature = SiteFeature.find_by_id(params[:path][0]) || SiteFeature.new

    @paragraph_index = params[:para_index]

    @feature.attributes = params[:feature]
    @feature.admin_user = myself
    @feature.validate_xml = true unless params[:ignore_xml_errors] # Require valid XML or a an override
    if @feature.save
        @saved = true
        @return = params[:return]
        if @paragraph_index
          @available_features = SiteFeature.single_feature_type_hash(@feature.site_template_id,@feature.feature_type)
        end
        
        expire_site
    elsif @feature.errors.on(:invalid_html)
        @invalid_html = true
    end
    
  end

end
