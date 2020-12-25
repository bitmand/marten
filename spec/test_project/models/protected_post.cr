class ProtectedPost < Marten::DB::Model
  field :id, :auto, primary_key: true
  field :post, :one_to_many, to: Post, on_delete: :protect
end