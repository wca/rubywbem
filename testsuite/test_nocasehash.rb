#
# Copyright 2006, Red Hat, Inc
# Scott Seago <sseago@redhat.com>
#
# derived from pywbem, written by Tim Potter <tpot@hp.com>, Martin Pool <mbp@hp.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#   
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#

#
# Test case-insensitive hash implementation.
#

require "comfychair"
require "validate"
require "wbem"

module WBEM
    module Test

        class TestInit < Comfychair::TestCase
            def runtest

                # Basic init
                d = NocaseHash.new()
                self.assert_(d.length == 0)

                # Initialise from sequence object
                d = NocaseHash.new([['Dog', 'Cat'], ['Budgie', 'Fish']])
                self.assert_(d.length == 2)
                self.assert_(d['Dog'] == 'Cat' || d['Budgie'] == 'Fish')

                # Initialise from mapping object
                d = NocaseHash.new({'Dog' => 'Cat', 'Budgie' => 'Fish'})
                self.assert_(d.length == 2)
                self.assert_(d['Dog'] == 'Cat' || d['Budgie'] == 'Fish')

                # Initialise from kwargs (not really kwargs for ruby)
                d = NocaseHash.new("Dog" => 'Cat', "Budgie" => 'Fish')
                self.assert_(d.length == 2)
                self.assert_(d['Dog'] == 'Cat' || d['Budgie'] == 'Fish')
            end
        end

        class BaseTest < Comfychair::TestCase
            attr_reader :d
            def setup
                @d = NocaseHash.new()
                @d['Dog'] = 'Cat'
                @d['Budgie'] = 'Fish'
            end
        end

        class TestGetitem < BaseTest
            def runtest
                self.assert_(self.d['dog'] == 'Cat')
                self.assert_(self.d['DOG'] == 'Cat')
            end
        end

        class TestLen < BaseTest
            def runtest
                self.assert_(self.d.length == 2)
            end
        end

        class TestSetitem < BaseTest
            def runtest

                self.d['DOG'] = 'Kitten'
                self.assert_(self.d['DOG'] == 'Kitten')
                self.assert_(self.d['Dog'] == 'Kitten')
                self.assert_(self.d['dog'] == 'Kitten')

                # Check that using a non-string key raises an exception

                begin
                    self.d[1234] = '1234'
                rescue IndexError
                else
                    self.fail('IndexError expected')
                end
            end
        end

        class TestDelitem < BaseTest
            def runtest
                self.d.delete('DOG')
                self.d.delete('budgie')
                self.assert_(self.d.keys() == [])
            end
        end

        class TestHasKey < BaseTest
            def runtest
                self.assert_(self.d.has_key?('DOG'))
                self.assert_(self.d.has_key?('budgie'))
                self.assert_(!self.d.has_key?(1234))
            end
        end

        class TestKeys < BaseTest
            def runtest
                keys = self.d.keys()
                animals = ['Budgie', 'Dog']
                animals.each do |a|
                    self.assert_(keys.include?(a))
                    keys.delete(a)
                end
                self.assert_(keys == [])
            end
        end

        class TestValues < BaseTest
            def runtest
                values = self.d.values()
                animals = ['Cat', 'Fish']
                animals.each do |a|
                    self.assert_(values.include?(a))
                    values.delete(a)
                end
                self.assert_(values == [])
            end
        end

        class TestItems < BaseTest
            def runtest
                items = self.d.to_a
                animals = [['Dog', 'Cat'], ['Budgie', 'Fish']]
                animals.each do |a|
                    self.assert_(items.include?(a))
                    items.delete(a)
                end
                self.assert_(items == [])
            end
        end

        class TestClear < BaseTest
            def runtest
                self.d.clear()
                self.assert_(self.d.length == 0)
            end
        end

        class TestUpdate < BaseTest
            def runtest
                self.d.clear()
                self.d.update({'Chicken' => 'Ham'})
                self.assert_(self.d.keys() == ['Chicken'])
                self.assert_(self.d.values() == ['Ham'])
            end
        end

        class TestCopy < BaseTest
            def runtest
                c = self.d.copy()
                self.assert_equal(c, self.d)
                self.assert_(c.is_a?(NocaseHash))
                c['Dog'] = 'Kitten'
                self.assert_(self.d['Dog'] == 'Cat')
                self.assert_(c['Dog'] == 'Kitten')
            end
        end

#class TestGet(BaseTest):
#    def runtest(self):
#        self.assert_(self.d.get('Dog', 'Chicken') == 'Cat')
#        self.assert_(self.d.get('Ningaui') == None)
#        self.assert_(self.d.get('Ningaui', 'Chicken') == 'Chicken')
#
#class TestSetDefault < BaseTest
#    def runtest
#        self.d.setdefault('Dog', 'Kitten')
#        self.assert_(self.d['Dog'] == 'Cat')
#        self.d.setdefault('Ningaui', 'Chicken')
#        self.assert_(self.d['Ningaui'] == 'Chicken')

#class TestPopItem < BaseTest
#    def runtest
#        pass

        class TestEqual < BaseTest
            def runtest
                c = NocaseHash.new({'dog' => 'Cat', 'Budgie' => 'Fish'})
                self.assert_(self.d == c)
                c['Budgie'] = 'fish'
                self.assert_(self.d != c)
            end
        end

        class TestContains < BaseTest
            def runtest
                self.assert_(self.d.include?('dog'))
                self.assert_(self.d.include?('Dog'))
                self.assert_(!self.d.include?('Cat'))
            end
        end

#class TestIterkeys < BaseTest
#    def runtest
#        for k in self.d.iterkeys():
#            self.assert_(k in ['Budgie', 'Dog'])
#
#class TestItervalues < BaseTest
#    def runtest
#        for v in self.d.itervalues():
#            self.assert_(v in ['Cat', 'Fish'])
#
#class TestIteritems < BaseTest
#    def runtest
#        for i in self.d.iteritems():
#            self.assert_(i in [('Budgie', 'Fish'), ('Dog', 'Cat')])

        TESTS = [
                 TestInit,
                 TestGetitem,
                 TestSetitem,
                 TestDelitem,
                 TestLen,
                 TestHasKey,
                 TestKeys,
                 TestValues,
                 TestItems,
                 TestClear,
                 TestUpdate,
                 TestCopy,
                 #    TestGet,
                 #    TestSetDefault,
                 #    TestPopItem,
                 TestEqual,
                 TestContains,
                 #    TestIterkeys,
                 #    TestItervalues,
                 #    TestIteritems,
                ]
        
        if __FILE__ == $0
            Comfychair.main(TESTS)
        end
    end
end
