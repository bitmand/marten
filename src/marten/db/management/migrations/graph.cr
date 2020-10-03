module Marten
  module DB
    module Management
      module Migrations
        # Represents a directed acyclic graph of migrations.
        #
        # In such graph, every migration corresponds to a node in the graph while dependencies between migrations
        # correspond to edges. Thus if a migration X depends on a migration Y, an edge between Y and X will be defined
        # indicating that Y must be applied before X.
        class Graph
          @nodes = {} of String => Node

          # Adds a migration object to the graph.
          def add_node(migration : Migration)
            @nodes[migration.id] = Node.new(migration)
          end

          # Configures a migration dependency.
          def add_dependency(migration : Migration, dependency_id : String)
            raise_unknown_node(dependency_id) unless @nodes.has_key?(dependency_id)
            @nodes[migration.id].add_parent(@nodes[dependency_id])
            @nodes[dependency_id].add_child(@nodes[migration.id])
          end

          # Verifies that the graph does not contain cycles.
          def ensure_acyclic_property : Nil
            seen = [] of String

            # Perform a DFS traversal of the directed graph and verifies that no cycles are present.
            @nodes.keys.each do |node_id|
              acyclic_dfs_traversal(node_id, seen, forwards: false) unless seen.includes?(node_id)
            end
          end

          # Return the leaves of the graph.
          #
          # Leaves correspond to migration nodes that don't have any child (that is no other migrations depend on them).
          def leaves
            leaves = Set(Node).new
            @nodes.values.each do |node|
              next unless node.children.all? { |n| n.migration.class.app_config != node.migration.class.app_config }
              leaves << node
            end
            leaves.to_a.sort { |n1, n2| n1.migration.id <=> n2.migration.id }
          end

          # Returns an array of migration nodes to unapply starting from a specific node migration.
          #
          # The returned array will start with the nodes that depend on the target node and will end with the target
          # node. The resulting "path" should be followed in order to unapply the migration corresponding to the target
          # node.
          def path_backward(target_node)
            path = acyclic_dfs_traversal(target_node.migration.id, forwards: false)
            path.map { |id| @nodes[id] }
          end

          # Returns an array of migration nodes to apply starting from a specific node migration.
          #
          # The returned array will start with the depdendencies of the target node and will end with the target node.
          # The resulting "path" should be followed in order to apply the migration corresponding to the target node.
          def path_forward(target_node)
            path = acyclic_dfs_traversal(target_node.migration.id, forwards: true)
            path.map { |id| @nodes[id] }
          end

          # Setup a replacement migration.
          #
          # From a `Marten::DB::Migration` object defining replacements, this method ensures that all the "replaced"
          # migrations are removed from the current graph. All other migrations referencing the replaced migrations are
          # updated to reference the replacing migration.
          def setup_replacement(migration : Migration)
            replacement_node = @nodes.fetch(migration.id) { raise_unknown_node(migration.id) }

            migration.class.replacement_ids.each do |replaced_id|
              replaced_node = @nodes.delete(replaced_id)

              unless replaced_node.nil?
                replaced_node.children.each do |child|
                  child.parents.delete(replaced_node)
                  # The replacement node should now have the replaced node child as its own child, the considered child
                  # node should have the replacement node as its parent. This should only be done when the child is not
                  # replaced by the current replacement node too.
                  if migration.class.replacement_ids.includes?(child.migration.id)
                    replacement_node.add_child(child)
                    child.add_parent(replacement_node)
                  end
                end

                replacement_node.parents.each do |parent|
                  parent.children.delete(replaced_node)
                  # The replacement node should now have the replaced node parent as its own parent, and the considered
                  # parent node should have the replacement node as a child. This should only be done if the parent is
                  # not going to be replaced too.
                  if migration.class.replacement_ids.includes?(parent.migration.id)
                    replacement_node.add_parent(parent)
                    parent.add_child(replacement_node)
                  end
                end
              end
            end
          end

          # Teardown a replacement migration.
          #
          # From a `Marten::DB::Migration` object defining replacements, this method ensures that the replacement
          # migration is removed from the graph and that the replacement migrations reference the replacement migration
          # child nodes.
          def teardown_replacement(migration : Migration)
            replacement_node = @nodes.delete(migration.id) { raise_unknown_node(migration.id) }

            replaced_nodes = Set(Node).new
            replaced_nodes_parents = Set(Node).new

            migration.class.replacement_ids.each do |replaced_id|
              replaced_node = @nodes[replaced_id]?
              unless replaced_node.nil?
                replaced_nodes << replaced_node
                replaced_node.parents.each { |n| replaced_nodes_parents << n }
              end
            end

            # A replacement migration usually replaces all previous migrations. But if the replacement migration is not
            # used, then only the latest replaced nodes have to be patched so that the initial replacement migration is
            # discarded.
            replaced_nodes -= replaced_nodes_parents

            replacement_node.children.each do |child|
              child.parents.delete(replacement_node)
              replaced_nodes.each do |replaced_node|
                replaced_node.add_child(child)
                child.add_parent(replaced_node)
              end
            end

            replacement_node.parents.each do |parent|
              parent.children.delete(replacement_node)
            end
          end

          # Returns the project state corresponding to the considered graph of mutation nodes.
          def to_project_state
            leaf_nodes = leaves
            project_state = ProjectState.new
            return project_state if leaf_nodes.empty?

            plan = [] of Migration

            # Generates a plan forward each leaf node in order to get a global migration plan.
            leaf_nodes.each do |leaf_node|
              path_forward(leaf_node).each do |node|
                plan << node.migration unless plan.includes?(node.migration)
              end
            end

            plan.each do |migration|
              project_state = migration.mutate_state(project_state, preserve: false)
            end

            project_state
          end

          private def acyclic_dfs_traversal(node_id, seen = [] of String, chain = [] of String, forwards = true)
            nodes_to_process = forwards ? @nodes[node_id].parents : @nodes[node_id].children
            nodes_to_process.each do |processed_node|
              processed_node_id = processed_node.migration.id
              if chain.includes?(processed_node_id)
                raise Errors::CircularDependency.new("Circular dependency identified up to '#{processed_node_id}'")
              end
              chain << processed_node_id
              acyclic_dfs_traversal(processed_node_id, seen, chain, forwards) unless seen.includes?(processed_node_id)
            end
            seen << node_id
          end

          private def raise_unknown_node(node_id)
            raise Errors::UnknownNode.new("Unknown node for migration ID '#{node_id}'")
          end
        end
      end
    end
  end
end