require File.dirname(__FILE__) + '/../test_helper'

class VirtualCommunityTest < Test::Unit::TestCase
  fixtures :virtual_communities

  def test_exists_default_and_it_is_unique
    VirtualCommunity.delete_all
    vc = VirtualCommunity.new(:name => 'Test Community')
    vc.is_default = true
    assert vc.save

    vc2 = VirtualCommunity.new(:name => 'Another Test Community')
    vc2.is_default = true
    assert !vc2.valid?
    assert vc2.errors.invalid?(:is_default)

    assert_equal vc, VirtualCommunity.default
  end

  def test_acts_as_configurable
    vc = VirtualCommunity.new(:name => 'Testing VirtualCommunity')
    assert_kind_of Array, vc.settings
    vc.settings[:some_setting] = 1
    assert vc.save
    assert_equal 1, vc.settings[:some_setting]
    assert_kind_of ConfigurableSetting, vc.settings.first
  end

  def test_available_features
    assert_kind_of Hash, VirtualCommunity.available_features
  end

  def test_features
    v = virtual_communities(:colivre_net)
    v.enable('feature1')
    assert v.enabled?('feature1')
    v.disable('feature1')
    assert !v.enabled?('feature1')
  end

  def test_enabled_features
    v = virtual_communities(:colivre_net)
    v.enabled_features = [ 'feature1', 'feature2' ]
    assert v.enabled?('feature1') && v.enabled?('feature2') && !v.enabled?('feature3')
  end

  def test_enabled_features_no_features_enabled
    v = virtual_communities(:colivre_net)
    v.enabled_features = nil
    assert !v.enabled?('feature1') && !v.enabled?('feature2') && !v.enabled?('feature3')
  end

  def test_name_is_mandatory
    v = VirtualCommunity.new
    v.valid?
    assert v.errors.invalid?(:name)
    v.name = 'blablabla'
    v.valid?
    assert !v.errors.invalid?(:name)
  end

end
