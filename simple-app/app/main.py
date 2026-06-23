from flask import Flask, jsonify, request, make_response


app = Flask(__name__)

users = [
    {'id': 1, 'name': 'Игорь', 'email': 'igor@mail.rr'},
    {'id': 2, 'name': 'Александр', 'email': 'alex@mail.rr'}, 
    {'id': 3, 'name': 'Иван', 'email': 'ivan@mail.rr'}
]

next_id = 4



@app.route('/')
def hello():
    return jsonify({'message': 'Hello, World!'})

@app.route('/health')
def health():
    return jsonify({'users': 'ok'}), 200


@app.route('/api/users', methods=['POST'])
def create_user():
    global next_id

    data = request.get_json()

    if not data:
        return jsonify({'error': 'Тело запросы должно быть JSON файлом'}), 400
    if 'name' not in data:
        return jsonify({'error': 'Отсутствует поле name оно обязательно'}), 400
    if 'email' not in data:
        return jsonify({'error': 'Отсутствует поле email оно обязательно'}), 400
    
    new_user = {
        'id': next_id,
        'name': data['name'],
        'email': data['email']
    }

    users.append(new_user)

    next_id += 1

    return jsonify(new_user), 201

@app.route('/api/users/<int:users_id>', methods=['GET'])
def get_user(users_id):
    user = None
    for u in users:
        if u['id'] == users_id:
            user = u
            break

    if user is None:
        return jsonify({'error':f'пользователь с id {users_id} не найден'}), 404
    
    return jsonify(user)

@app.route('/api/users', methods=['GET'])
def get_users():
    return jsonify({'users':users})

@app.route('/api/users/<int:users_id>', methods=['DELETE'])
def delete_user(users_id):
    global users

    user = None
    for u in users:
        if u['id'] == users_id:
            user = u
            break

    if user is None:
        return jsonify({'error':f'пользователь с id {users_id} не найден'}), 404
    
    new_users = []
    for u in users:
        if u['id'] != users_id:
            new_users.append(u)
    
    users = new_users
    
    return jsonify({'message': f'пользователь с id {users_id} удален'}), 200
    
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)