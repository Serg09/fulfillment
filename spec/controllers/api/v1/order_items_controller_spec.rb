require 'rails_helper'

describe Api::V1::OrderItemsController, type: :controller do
  let (:client) { FactoryGirl.create(:client) }
  let (:order) { FactoryGirl.create(:order, client: client, ship_method: nil) }
  let!(:item) { FactoryGirl.create(:order_item, order: order, quantity: 3) }
  let (:product) { FactoryGirl.create(:product, price: 9.99) }
  let (:attributes) do
    {
      sku: product.sku,
      quantity: 3
    }
  end

  context 'when an auth token is present' do
    before do
      request.headers['Authorization'] = "Token token=#{client.auth_token}"
    end

    context 'and the order belongs to the client' do
      describe 'get :index' do
        it 'is successful' do
          get :index, order_id: order
          expect(response).to have_http_status :success
        end

        it 'returns a list of items in the order' do
          get :index, order_id: order
          result = JSON.parse(response.body, symbolize_names: true)
          skus = result.map{|i| i[:sku]}
          expect(skus).to eq [item.sku]
        end
      end

      context 'and the order is incipient' do
        describe 'post :create' do
          it 'is successful' do
            post :create, order_id: order, item: attributes
            expect(response).to have_http_status :success
          end

          it 'creates an order item record' do
            expect do
              post :create, order_id: order, item: attributes
            end.to change(order.items, :count).by(1)
          end

          it 'returns the new item' do
            post :create, order_id: order, item: attributes
            result = JSON.parse(response.body, symbolize_names: true)
            expect(result).to include({
              sku: product.sku,
              quantity: 3,
              unit_price: 9.99,
              extended_price: 29.97
            })
          end
        end

        describe 'patch :update' do
          it 'returns http status success' do
            patch :update, id: item, item: {quantity: 4}
            expect(response).to have_http_status :success
          end

          it 'updates the order item' do
            expect do
              patch :update, id: item, item: {quantity: 4}
              item.reload
            end.to change(item, :quantity).to(4)
          end

          it 'returns the item' do
            patch :update, id: item, item: {quantity: 4}
            result = JSON.parse(response.body, symbolize_names: true)
            expect(result).to include quantity: 4
          end
        end

        describe 'delete :destroy' do
          it 'is successful' do
            delete :destroy, id: item
            expect(response).to have_http_status :success
          end

          it 'deletes the order item record' do
            expect do
              delete :destroy, id: item
            end.to change(order.items, :count).by(-1)
          end
        end
      end

      shared_examples_for 'an immutable order' do
        describe 'post :create' do
          it 'returns http status "conflict"' do
            post :create, order_id: order, item: attributes
            expect(response).to have_http_status :conflict
          end

          it 'does not create an order item record' do
            expect do
              post :create, order_id: order, item: attributes
            end.not_to change(order.items, :count)
          end

          it 'does not return an item' do
            post :create, order_id: order, item: attributes
            expect(response.body).not_to match /sku/
          end

          it 'returns an error message' do
            post :create, order_id: order, item: attributes
            result = JSON.parse(response.body, symbolize_names: true)
            expect(result).to include message: 'The order cannot be modified in its current state.'
          end
        end

        describe 'patch :update' do
          it 'returns http status "conflict"' do
            patch :update, id: item, item: {quantity: 4}
            expect(response).to have_http_status :conflict
          end

          it 'does not update the order item' do
            expect do
              patch :update, id: item, item: {quantity: 4}
              item.reload
            end.not_to change(item, :quantity)
          end

          it 'does not return the item' do
            patch :update, id: item, item: {quantity: 4}
            expect(response.body).not_to match /sku/
          end

          it 'returns an error message' do
            patch :update, id: item, item: {quantity: 4}
            result = JSON.parse(response.body, symbolize_names: true)
            expect(result).to include message: 'The order cannot be modified in its current state.'
          end
        end

        describe 'delete :destroy' do
          it 'returns http status "conflict"' do
            delete :destroy, id: item
            expect(response).to have_http_status :conflict
          end

          it 'does not delete the order item record' do
            expect do
              delete :destroy, id: item
            end.not_to change(OrderItem, :count)
          end

          it 'returns an error message' do
            delete :destroy, id: item
            result = JSON.parse(response.body, symbolize_names: true)
            expect(result).to include message: 'The order cannot be modified in its current state.'
          end
        end
      end

      context 'and the order is submitted' do
        it_behaves_like 'an immutable order' do
          let (:order) { FactoryGirl.create :submitted_order }
        end
      end

      context 'and the order is exporting' do
        it_behaves_like 'an immutable order' do
          let (:order) { FactoryGirl.create :exporting_order }
        end
      end

      context 'and the order is exported' do
        it_behaves_like 'an immutable order' do
          let (:order) { FactoryGirl.create :exported_order }
        end
      end

      context 'and the order is processing' do
        it_behaves_like 'an immutable order' do
          let (:order) { FactoryGirl.create :processing_order }
        end
      end

      context 'and the order is shipped' do
        it_behaves_like 'an immutable order' do
          let (:order) { FactoryGirl.create :shipped_order }
        end
      end

      context 'and the order is rejected' do
        it_behaves_like 'an immutable order' do
          let (:order) { FactoryGirl.create :rejected_order }
        end
      end
    end

    context 'and the order does not belong to the client' do
      let (:other_client) { FactoryGirl.create(:client) }
      before do
        request.headers['Authorization'] = "Token token=#{other_client.auth_token}"
      end

      describe 'get :index' do
        it 'returns http status "not found"' do
          get :index, order_id: order
          expect(response).to have_http_status :not_found
        end

        it 'does not return an order items' do
          get :index, order_id: order
          expect(response.body).not_to match /sku/
        end
      end

      describe 'post :create' do
        it 'returns http status "not found"' do
          post :create, order_id: order, item: attributes
          expect(response).to have_http_status :not_found
        end

        it 'does not create an order item record' do
          expect do
            post :create, order_id: order, item: attributes
          end.not_to change(OrderItem, :count)
        end

        it 'does not return the new item' do
          post :create, order_id: order, item: attributes
          expect(response.body).not_to match /sku/
        end
      end

      describe 'patch :update' do
        it 'returns http status "not found"' do
          patch :update, id: item, item: {quantity: 1}
          expect(response).to have_http_status :not_found
        end

        it 'does not update the order item' do
          expect do
            patch :update, id: item, item: {quantity: 1}
            item.reload
          end.not_to change(item, :quantity)
        end

        it 'does not return the item' do
          patch :update, id: item, item: {quantity: 1}
          expect(response.body).not_to match /sku/
        end
      end
    end
  end

  context 'when an auth token is absent' do
    describe 'get :index' do
      it 'returns http status "unauthorized"' do
        get :index, order_id: order
        expect(response).to have_http_status :unauthorized
      end

      it 'does not return an order items' do
        get :index, order_id: order
        expect(response.body).not_to match /sku/
      end
    end

    describe 'post :create' do
      it 'returns http status "unauthorized"' do
        post :create, order_id: order, item: attributes
        expect(response).to have_http_status :unauthorized
      end

      it 'does not create an order item record' do
        expect do
          post :create, order_id: order, item: attributes
        end.not_to change(OrderItem, :count)
      end

      it 'does not return the new item' do
        post :create, order_id: order, item: attributes
        expect(response.body).not_to match /sku/
      end
    end

    describe 'patch :update' do
      it 'returns http status "unauthorized"' do
        patch :update, id: item, item: {quantity: 1}
        expect(response).to have_http_status :unauthorized
      end

      it 'does not update the order item' do
        expect do
          patch :update, id: item, item: {quantity: 1}
          item.reload
        end.not_to change(item, :quantity)
      end

      it 'does not return the item' do
        patch :update, id: item, item: {quantity: 1}
        expect(response.body).not_to match /sku/
      end
    end

    describe 'delete :destroy' do
      it 'returns status "unauthorized"' do
        delete :destroy, id: item
        expect(response).to have_http_status :unauthorized
      end

      it 'does not delete the order item' do
        expect do
          delete :destroy, id: item
        end.not_to change(OrderItem, :count)
      end

      it 'does not return the order item' do
        delete :destroy, id: item
        expect(response.body).not_to match /sku/
      end
    end
  end
end
