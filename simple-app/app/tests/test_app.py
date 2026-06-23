import pytest

from main import app


@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_hello_edpoint(client):
    response = client.get('/')
    assert response.status_code == 200

    data = response.get_json()
    assert 'message' in data, "Ответ должен содержать поле 'message'"
    assert data['message'] == 'Hello, World!', "Сообщение должно быть 'Hello, World!'"

def test_health_endpoint(client):
    response = client.get('/health')
    assert response.status_code == 200

    data = response.get_json()
    assert 'users' in data, "Ответ должен содержать поле 'status'"
    assert data['users'] == 'ok', "Статус должен быть 'ok'"

def test_get_users_endpoint(client):
    response = client.get('/api/users')
    assert response.status_code == 200

    data = response.get_json()
    assert 'users' in data, "Ответ должен содержать поле 'users'"
    assert isinstance(data['users'], list), "Поле 'users' должно быть списком"
    assert len(data['users']) > 0, "Список пользователей не должен быть пустым"

    first_user = data['users'][0]
    assert 'id' in first_user, "Каждый пользователь должен содержать поле 'id'"
    assert 'name' in first_user, "Каждый пользователь должен содержать поле 'name'"
    assert 'email' in first_user, "Каждый пользователь должен содержать поле 'email'"

def test_create_user_endpoint(client):
    new_user_data = {
        'name': 'New User',
        'email': 'newuser@example.com'
    }

    response = client.post('/api/users', json=new_user_data, headers={'Content-Type':'application/json'})

    assert response.status_code == 201

    data = response.get_json()
    assert 'id' in data, "Новый пользователь должен содержать поле 'id'"
    assert data['name'] == new_user_data['name'], "Имя пользователя должно совпадать"
    assert data['email'] == new_user_data['email'], "Email пользователя должен совпадать"
    assert isinstance(data['id'], int), "Поле 'id' должно быть целым числом"

    get_response = client.get('/api/users')
    users_data = get_response.get_json()

    last_user = users_data['users'][-1]
    assert last_user['name'] == data['name'], "Имя нового пользователя должен совпадать с последним именем в списке пользователей"
    assert last_user['email'] == data['email'], "Email нового пользователя должен совпадать с последним email в списке пользователей"

def test_create_user_missing_email(client):
    invalid_data = {
        'name': 'Invalid User',
    }

    response = client.post('/api/users', json=invalid_data, headers={'Content-Type':'application/json'})

    assert response.status_code == 400

    data = response.get_json()
    assert 'error' in data, "Ответ должен содержать поле 'error'"
    assert 'email' in data['error'].lower(), "Ошибка должна содержать поле 'email'"

    get_response = client.get('/api/users')
    users_data = get_response.get_json()

    found = []
    for u in users_data['users']:
        if u['name'] == 'Invalid User':
            found.append(u)
    assert len(found) == 0, "Пользователь с именем 'Invalid User' должен быть удален"

def test_get_user_by_id(client):
    response = client.get('/api/users/1')

    assert response.status_code == 200
    data = response.get_json()

    assert data['id'] == 1, "ID пользователя должен быть 1"
    assert 'name' in data, "Ответ должен содержать поле 'name'"
    assert 'email' in data, "Ответ должен содержать поле 'email'"


def test_create_user_missing_name(client):
    invalid_data = {
        'email': 'invalid@example.com',
    }

    response = client.post('/api/users', json=invalid_data)

    assert response.status_code == 400
    data = response.get_json()

    assert 'error' in data, "Ответ должен содержать поле 'error'"
    assert 'name' in data['error'].lower(), "Ошибка должна содержать поле 'name'"

def test_create_user_empty_json(client):
    response = client.post('/api/users', json={})

    assert response.status_code == 400
    data = response.get_json()

    assert 'error' in data, "Ответ должен содержать поле 'error'"

def test_delete_user_success(client):
    new_user = {
        'name': 'Test User',
        'email': 'test@example.com'
    }

    create_response = client.post('/api/users', json=new_user)
    assert create_response.status_code == 201
    create_data = create_response.get_json()
    user_id = create_data['id']

    delete_response = client.delete(f'/api/users/{user_id}')
    assert delete_response.status_code == 200
    delete_data = delete_response.get_json()
    assert 'message' in delete_data, 'Ответ должен содержать поле "message"'

    get_response = client.get(f'/api/users/{user_id}')
    assert get_response.status_code == 404