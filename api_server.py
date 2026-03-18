from flask import Flask, jsonify
from flask import request 
from werkzeug.security import generate_password_hash, check_password_hash
import pymysql
import pymysql.cursors 
import os 
import smtplib 
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from werkzeug.utils import secure_filename 
from flask import send_from_directory 
import requests 
import os 

# --- Configurações do MySQL  ---
MYSQL_HOST = "127.0.0.1"
MYSQL_USUARIO = "mapl_user"
MYSQL_SENHA =  "5an5un65@L"
MYSQL_BANCO = "aplicativotrilhamapl"
MYSQL_PORTA = 3306
ADMIN_REGISTER_CODE = "MAPL_ADMIN_2025"

# Inicializa o aplicativo Flask
app = Flask(__name__)

def send_welcome_email(user_email, user_name):
    """Envia um e-mail de boas-vindas para o novo usuário."""

    sender_email = os.environ.get('EMAIL_USER')
    sender_password = os.environ.get('EMAIL_PASS')

    if not sender_email or not sender_password:
        print("[API_SERVER] ERRO DE E-MAIL: Variáveis EMAIL_USER ou EMAIL_PASS não definidas.")
        return False 

    message = MIMEMultipart("alternative")
    message["Subject"] = "Bem-vindo ao Aplicativo de Trilhas!"
    message["From"] = sender_email
    message["To"] = user_email

    html = f"""
    <html>
    <body>
        <h3>Olá, {user_name}!</h3>
        <p>Seu cadastro no Aplicativo de Apoio à Trilha foi realizado com sucesso.</p>
        <p>Estamos felizes em ter você conosco.</p>
        <p>Atenciosamente,<br>Equipe MAPL</p>
    </body>
    </html>
    """

    message.attach(MIMEText(html, "html"))

    context = ssl.create_default_context()
    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=context) as server:
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, user_email, message.as_string())
        print(f"[API_SERVER] E-mail de boas-vindas enviado para {user_email}")
        return True
    except Exception as e:
        print(f"[API_SERVER] ERRO AO ENVIAR E-MAIL: {e}")
        return False

UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def conectar_mysql():
    """Função auxiliar para conectar ao banco."""
    try:
        conexao = pymysql.connect(
            host=MYSQL_HOST,
            user=MYSQL_USUARIO,
            password=MYSQL_SENHA,
            database=MYSQL_BANCO,
            port=MYSQL_PORTA,
            cursorclass=pymysql.cursors.DictCursor 
        )
        return conexao
    except pymysql.Error as err:
        print(f"[API_SERVER] Erro ao conectar ao MySQL: {err}")
        return None

# --- ENDPOINT 1: Dashboard do Operador de Base ---
@app.route('/api/dashboard/geral', methods=['GET'])
def get_dashboard_geral():
    print("[API_SERVER] Recebida requisição para /api/dashboard/geral")
    conexao = conectar_mysql()
    if conexao is None:
        return jsonify({"erro": "Nao foi possivel conectar ao banco"}), 500

    try:
        with conexao.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) as total_usuarios FROM usuarios")
            total_usuarios = cursor.fetchone()['total_usuarios']

            cursor.execute("SELECT COUNT(*) as total_eventos FROM eventos_passagem")
            total_eventos = cursor.fetchone()['total_eventos']

            cursor.execute("SELECT COUNT(*) as total_agendamentos FROM agendamentos")
            total_agendamentos = cursor.fetchone()['total_agendamentos']

            
            cursor.execute("SELECT COUNT(*) as qtd FROM usuarios WHERE tipo_perfil = 1")
            qtd_trilheiros = cursor.fetchone()['qtd']

            cursor.execute("SELECT COUNT(*) as qtd FROM usuarios WHERE tipo_perfil = 2")
            qtd_operadores = cursor.fetchone()['qtd']

            cursor.execute("SELECT COUNT(*) as qtd FROM usuarios WHERE tipo_perfil = 3")
            qtd_admins = cursor.fetchone()['qtd']

        return jsonify({
            "total_usuarios": total_usuarios,
            "total_eventos_passagem": total_eventos,
            "total_agendamentos": total_agendamentos,
            # Novos campos adicionados:
            "qtd_trilheiros": qtd_trilheiros,
            "qtd_operadores": qtd_operadores,
            "qtd_admins": qtd_admins
        })

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao: conexao.close()

# --- ENDPOINT 2: Verificação do Guia por Tag ---
@app.route('/api/eventos/tag/<int:tag_id>', methods=['GET'])
def get_eventos_por_tag(tag_id):
    print(f"[API_SERVER] Recebida requisição para /api/eventos/tag/{tag_id}")
    conexao = conectar_mysql()
    if conexao is None:
        return jsonify({"erro": "Nao foi possivel conectar ao banco"}), 500
    
    try:
        with conexao.cursor() as cursor:
            sql = """
            SELECT 
                e.timestamp_leitura, 
                e.direcao, 
                u.nome as nome_usuario,
                u.email as email_usuario
            FROM eventos_passagem e
            JOIN usuarios u ON e.id_usuario = u.id
            WHERE e.id_tag = %s
            ORDER BY e.timestamp_leitura DESC;
            """
            cursor.execute(sql, (tag_id,))
            eventos = cursor.fetchall()


            return jsonify({
                "tag_solicitada": tag_id,
                "passaram_por_aqui": eventos
            })

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao:
            conexao.close()

# --- ENDPOINT 3: Registro de Novo Usuário (COM FOTO) ---
@app.route('/api/register', methods=['POST'])
def register_user():
    print("[API_SERVER] Recebida requisição para /api/register (com form-data)")

    # 1. Pega os dados do formulário (NÃO é mais request.json)
    data = request.form

    nome = data.get('nome')
    email = data.get('email')
    cpf = data.get('cpf')
    senha = data.get('senha')
    tipo_perfil = int(data.get('tipo_perfil', 1))
    telefone = data.get('telefone')
    idade = data.get('idade')
    sexo = data.get('sexo')
    admin_code = data.get('admin_code')

    if not nome or not email or not senha:
        return jsonify({"erro": "Nome, e-mail e senha são obrigatórios"}), 400

    if tipo_perfil > 1 and admin_code != ADMIN_REGISTER_CODE:
        return jsonify({"erro": "Código de administrador inválido"}), 403

    senha_hash = generate_password_hash(senha)

    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Erro de conexão com BD"}), 500

    try:
        with conexao.cursor() as cursor:
            sql_insert_user = """
            INSERT INTO usuarios (nome, email, cpf, senha_hash, tipo_perfil, telefone, idade, sexo)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql_insert_user, (nome, email, cpf, senha_hash, tipo_perfil, telefone, idade, sexo))
            novo_id = cursor.lastrowid 
            url_foto_final = None # Padrão
            if 'foto_perfil' in request.files:
                file = request.files['foto_perfil']

                if file and allowed_file(file.filename):
                    extensao = file.filename.rsplit('.', 1)[1].lower()
                    filename = f"usuario_{novo_id}.{extensao}"
                    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
                    file.save(filepath)
                    url_foto_final = filename 
                    sql_update_photo = "UPDATE usuarios SET url_foto_perfil = %s WHERE id = %s"
                    cursor.execute(sql_update_photo, (url_foto_final, novo_id))

            conexao.commit()
            send_welcome_email(email, nome)

            return jsonify({
                "mensagem": "Usuário criado com sucesso!",
                "id_usuario": novo_id,
                "nome": nome,
                "tipo_perfil": tipo_perfil,
                "url_foto_perfil": url_foto_final
            }), 201

    except pymysql.Error as err:
        if conexao: conexao.rollback() 
        if err.args[0] == 1062:
            return jsonify({"erro": "E-mail já cadastrado"}), 409
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao: conexao.close()


# --- ENDPOINT 4: Login ---


@app.route('/api/login', methods=['POST'])
def login_user():
    print("[API_SERVER] Recebida requisição para /api/login")
    data = request.json
    login_input = data.get('email') 
    senha = data.get('senha')

    if not login_input or not senha:
        return jsonify({"erro": "Login e senha são obrigatórios"}), 400

    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Erro de conexão com BD"}), 500

    try:
        with conexao.cursor() as cursor:
            sql = "SELECT * FROM usuarios WHERE email = %s OR cpf = %s"
            cursor.execute(sql, (login_input, login_input))
            usuario = cursor.fetchone() 

            if not usuario:
                return jsonify({"erro": "Usuário não encontrado"}), 401

            if not check_password_hash(usuario['senha_hash'], senha):
                return jsonify({"erro": "Credenciais inválidas (senha)"}), 401

            return jsonify({
                "mensagem": "Login bem-sucedido!",
                "id_usuario": usuario['id'],
                "nome": usuario['nome'],
                "email": usuario['email'],
                "tipo_perfil": usuario['tipo_perfil'],
                "url_foto_perfil": usuario['url_foto_perfil'],
                "status_guia": usuario['status_guia'] if usuario['status_guia'] else 'offline'
            })

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao: conexao.close()

# --- ENDPOINT 5: Servidor de Arquivos Estáticos  ---
@app.route('/uploads/<path:filename>')
def serve_uploaded_file(filename):
    print(f"[API_SERVER] Servindo arquivo: {filename}")
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

# --- ENDPOINT 6: Iniciar uma Nova Trilha ---
@app.route('/api/trilha/iniciar', methods=['POST'])
def iniciar_trilha():
    data = request.json
    
    id_lider = data.get('id_usuario_lider')
    nome = data.get('nome')
    dificuldade = data.get('dificuldade')
    tipo = data.get('tipo') 
    duracao = data.get('duracao_estimada')
    notas = data.get('notas')
    
    participantes_ids = data.get('participantes_ids', [])     
    participantes_externos = data.get('participantes_externos', []) 
    
    precisa_guia = data.get('solicitar_guia', False)
    data_agendada = data.get('data_agendada')

    conexao = conectar_mysql()
    try:
        with conexao.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS trilha_participantes (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    trilha_id INT NOT NULL,
                    usuario_id INT NULL,  -- Pode ser NULL se for externo
                    nome_externo VARCHAR(255) NULL, -- Nome se for externo
                    FOREIGN KEY (trilha_id) REFERENCES trilhas(id) ON DELETE CASCADE
                )
            """)
            
            sql = """
            INSERT INTO trilhas (id_usuario_lider, nome, dificuldade, tipo, duracao_estimada, notas, criada_em, status)
            VALUES (%s, %s, %s, %s, %s, %s, NOW(), 'ativa')
            """
            cursor.execute(sql, (id_lider, nome, dificuldade, tipo, duracao, notas))
            trilha_id = cursor.lastrowid

            if tipo == 'Grupo' and participantes_ids:
                sql_part = "INSERT INTO trilha_participantes (trilha_id, usuario_id) VALUES (%s, %s)"
                for pid in participantes_ids:
                    if int(pid) != int(id_lider):
                        cursor.execute(sql_part, (trilha_id, pid))

            if tipo == 'Grupo' and participantes_externos:
                sql_ext = "INSERT INTO trilha_participantes (trilha_id, usuario_id, nome_externo) VALUES (%s, NULL, %s)"
                for nome_ext in participantes_externos:
                    cursor.execute(sql_ext, (trilha_id, nome_ext))

            if precisa_guia and data_agendada:
                sql_agenda = """
                INSERT INTO agendamentos (trilha_id, guia_id, data_agendada, status)
                VALUES (%s, NULL, %s, 'pendente')
                """
                cursor.execute(sql_agenda, (trilha_id, data_agendada))

        conexao.commit()
        return jsonify({"mensagem": "Trilha iniciada!", "trilha_id": trilha_id}), 201
        
    except pymysql.Error as err:
        return jsonify({"erro": str(err)}), 500
    finally:
        conexao.close()

# --- ENDPOINT 7: Buscar Detalhes de uma Trilha Ativa ---
@app.route('/api/trilha/detalhes/<int:trilha_id>', methods=['GET'])
def get_detalhes_trilha(trilha_id):
    print(f"[API_SERVER] Recebida requisição para /api/trilha/detalhes/{trilha_id}")
    conexao = conectar_mysql()
    if conexao is None:
        return jsonify({"erro": "Nao foi possivel conectar ao banco"}), 500

    try:
        with conexao.cursor() as cursor:
            sql_trilha = """
            SELECT 
                nome_trilha, dificuldade, tipo, notas,
                DATE_FORMAT(iniciada_em, '%%Y-%%m-%%dT%%H:%%i:%%sZ') as iniciada_em_iso,
                id_usuario_lider
            FROM trilhas_ativas 
            WHERE id = %s
            """
            cursor.execute(sql_trilha, (trilha_id,))
            trilha = cursor.fetchone()

            if not trilha:
                return jsonify({"erro": "Trilha não encontrada"}), 404

            id_lider = trilha.get('id_usuario_lider')
            sql_participantes = """
            SELECT nome, url_foto_perfil 
            FROM usuarios 
            WHERE id = %s
            """ 
            cursor.execute(sql_participantes, (id_lider,))
            participantes = cursor.fetchall()

            return jsonify({
                "trilha_info": trilha,
                "participantes": participantes 
            })

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao:
            conexao.close()

# --- ENDPOINT 8: Finalizar uma Trilha Ativa ---
@app.route('/api/trilha/finalizar/<int:trilha_id>', methods=['POST'])
def finalizar_trilha(trilha_id):
    print(f"[API_SERVER] Recebida requisição para /api/trilha/finalizar/{trilha_id}")
    conexao = conectar_mysql()
    if conexao is None:
        return jsonify({"erro": "Nao foi possivel conectar ao banco"}), 500

    try:
        with conexao.cursor() as cursor:
            sql = """
            UPDATE trilhas_ativas 
            SET status = 'Concluída', concluida_em = NOW() 
            WHERE id = %s
            """
            cursor.execute(sql, (trilha_id,))
            conexao.commit()

            return jsonify({
                "mensagem": "Trilha finalizada com sucesso!",
                "id_trilha_finalizada": trilha_id
            })

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao:
            conexao.close()

# --- ENDPOINT 9: Buscar Clima Local ---
@app.route('/api/clima', methods=['GET'])
def get_clima():
    lat = request.args.get('lat')
    lon = request.args.get('lon')
    api_key = os.environ.get('OPENWEATHER_API_KEY')

    if not lat or not lon:
        return jsonify({"erro": "Latitude (lat) e Longitude (lon) são obrigatórias"}), 400

    if not api_key:
        print("[API_SERVER] ERRO DE CLIMA: Variável OPENWEATHER_API_KEY não definida.")
        return jsonify({"erro": "Serviço de clima indisponível"}), 503

    url = f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={api_key}&units=metric&lang=pt_br"

    try:
        response = requests.get(url)
        data = response.json()

        if response.status_code != 200:
            return jsonify({"erro": data.get('message', 'Erro da API de Clima')}), response.status_code

        clima_filtrado = {
            "temp": data['main']['temp'],
            "sensacao_termica": data['main']['feels_like'],
            "descricao": data['weather'][0]['description'].capitalize(),
            "icone": data['weather'][0]['icon']
        }
        return jsonify(clima_filtrado)

    except Exception as e:
        return jsonify({"erro": f"Exceção na API de Clima: {e}"}), 500
    
# --- ENDPOINT 10: Histórico de Trilhas do Usuário ---
@app.route('/api/trilhas/usuario/<int:user_id>/historico', methods=['GET'])
def get_historico_usuario(user_id):
    print(f"[API_SERVER] Buscando histórico para o usuário {user_id}")
    conexao = conectar_mysql()
    if conexao is None:
        return jsonify({"erro": "Sem conexão com BD"}), 500
    
    try:
        with conexao.cursor() as cursor:
            sql = """
            SELECT 
                id, nome_trilha, dificuldade, tipo, duracao_estimada_min, notas,
                DATE_FORMAT(iniciada_em, '%%Y-%%m-%%dT%%H:%%i:%%sZ') as data_inicio,
                DATE_FORMAT(concluida_em, '%%Y-%%m-%%dT%%H:%%i:%%sZ') as data_fim
            FROM trilhas_ativas 
            WHERE id_usuario_lider = %s AND status = 'Concluída'
            ORDER BY iniciada_em DESC
            """
            cursor.execute(sql, (user_id,))
            historico = cursor.fetchall()
            
            return jsonify(historico)
            
    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao:
            conexao.close()

# --- ENDPOINT 11: Provisionar Nova Tag (Gerar ID) ---
@app.route('/api/tags/provisionar', methods=['POST'])
def provisionar_tag():
    print("[API_SERVER] Recebida requisição para provisionar nova tag")
    data = request.json
    uid_hardware = data.get('uid_hardware', 'desconhecido')

    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão com BD"}), 500
    
    try:
        with conexao.cursor() as cursor:
            sql = "INSERT INTO tags_fisicas (uid_hardware) VALUES (%s)"
            cursor.execute(sql, (uid_hardware,))
            conexao.commit()
            
            novo_logical_id = cursor.lastrowid
            
            return jsonify({
                "mensagem": "Tag registrada no sistema!",
                "proximo_id": novo_logical_id
            }), 201
            
    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao: conexao.close()
# --- ENDPOINT 12: Listar Tags Físicas ---
@app.route('/api/tags', methods=['GET'])
def listar_tags():
    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500
    try:
        with conexao.cursor() as cursor:
            cursor.execute("SELECT id, uid_hardware, criado_em FROM tags_fisicas ORDER BY id DESC")
            tags = cursor.fetchall()
            return jsonify(tags)
    except pymysql.Error as err:
        return jsonify({"erro": str(err)}), 500
    finally:
        if conexao: conexao.close()

# --- ENDPOINT 13: Deletar Tag (Para Rollback ou Gestão Manual) ---
@app.route('/api/tags/<int:tag_id>', methods=['DELETE'])
def deletar_tag(tag_id):
    print(f"[API_SERVER] Deletando tag ID: {tag_id}")
    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500
    try:
        with conexao.cursor() as cursor:
            cursor.execute("DELETE FROM tags_fisicas WHERE id = %s", (tag_id,))
            conexao.commit()
            return jsonify({"mensagem": "Tag deletada com sucesso"})
    except pymysql.Error as err:
        return jsonify({"erro": str(err)}), 500
    finally:
        if conexao: conexao.close()

# --- ENDPOINT 14: Deletar Conta do Usuário ---
@app.route('/api/usuario/<int:user_id>', methods=['DELETE'])
def deletar_usuario(user_id):
    print(f"[API_SERVER] Recebida solicitação para deletar usuário ID: {user_id}")
    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500
    
    try:
        with conexao.cursor() as cursor:
            cursor.execute("SELECT id FROM usuarios WHERE id = %s", (user_id,))
            if not cursor.fetchone():
                return jsonify({"erro": "Usuário não encontrado"}), 404
            cursor.execute("DELETE FROM usuarios WHERE id = %s", (user_id,))
            conexao.commit()
            
            print(f"[API_SERVER] Usuário {user_id} deletado com sucesso.")
            return jsonify({"mensagem": "Conta excluída com sucesso"})

    except pymysql.Error as err:
        print(f"[API_SERVER] Erro ao deletar usuário: {err}")
        return jsonify({"erro": f"Erro ao excluir conta: {err}"}), 500
    finally:
        if conexao: conexao.close()

# 15. Buscar Agendamentos do Guia (Para o Calendário e Cards)
@app.route('/api/guia/<int:guia_id>/agendamentos', methods=['GET'])
def get_agendamentos_guia(guia_id):
    print(f"[API_SERVER] Buscando agenda do guia {guia_id}")
    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500

    try:
        with conexao.cursor() as cursor:
            sql = """
            SELECT 
                a.id, a.data_agendada, a.status, a.nome_trilha, a.dificuldade,
                u.nome as nome_trilheiro, u.url_foto_perfil as foto_trilheiro
            FROM agendamentos a
            JOIN usuarios u ON a.id_trilheiro = u.id
            WHERE a.id_guia = %s
            ORDER BY a.data_agendada ASC
            """
            cursor.execute(sql, (guia_id,))
            agendamentos = cursor.fetchall()
            
            for ag in agendamentos:
                if ag['data_agendada']:
                    ag['data_agendada'] = ag['data_agendada'].strftime('%Y-%m-%d %H:%M:%S')

            return jsonify(agendamentos)
    except pymysql.Error as err:
        return jsonify({"erro": str(err)}), 500
    finally:
        if conexao: conexao.close()

# 16. Atualizar Status do Guia (Disponível / Offline)
@app.route('/api/guia/<int:guia_id>/status', methods=['PUT'])
def update_status_guia(guia_id):
    data = request.json
    novo_status = data.get('status') 
    
    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500

    try:
        with conexao.cursor() as cursor:
            sql = "UPDATE usuarios SET status_guia = %s WHERE id = %s"
            cursor.execute(sql, (novo_status, guia_id))
            conexao.commit()
            return jsonify({"mensagem": "Status atualizado", "novo_status": novo_status})
    except pymysql.Error as err:
        return jsonify({"erro": str(err)}), 500
    finally:
        if conexao: conexao.close()

# 17 ALTERAR A FOTO DE PERFIL
@app.route('/api/usuario/<int:user_id>/foto', methods=['PUT'])
def update_foto_perfil(user_id):
    print(f"[API_SERVER] Recebida solicitação de troca de foto para UID: {user_id}")
    
    if 'foto_perfil' not in request.files:
        return jsonify({"erro": "Nenhuma imagem enviada"}), 400
    
    file = request.files['foto_perfil']
    
    if file.filename == '':
        return jsonify({"erro": "Arquivo sem nome"}), 400

    if file and allowed_file(file.filename):
        conexao = conectar_mysql()
        if conexao is None: return jsonify({"erro": "Sem conexão com BD"}), 500

        try:
            import time
            timestamp = int(time.time())
            extensao = file.filename.rsplit('.', 1)[1].lower()
            filename = f"usuario_{user_id}_{timestamp}.{extensao}"
            
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(filepath)
            
            with conexao.cursor() as cursor:
                sql = "UPDATE usuarios SET url_foto_perfil = %s WHERE id = %s"
                cursor.execute(sql, (filename, user_id))
                conexao.commit()
                
            return jsonify({
                "mensagem": "Foto atualizada com sucesso",
                "url_nova_foto": filename
            })

        except pymysql.Error as err:
            return jsonify({"erro": f"Erro de SQL: {err}"}), 500
        finally:
            if conexao: conexao.close()
    
    return jsonify({"erro": "Arquivo não permitido"}), 400

# 18 Dados de agendamentos e eventos
@app.route('/api/dashboard/detalhado', methods=['GET']) 
def get_dashboard_detalhado(): 
    print("[API_SERVER] Recebida requisição para /api/dashboard/detalhado")
    conexao = conectar_mysql()
    if conexao is None:
        return jsonify({"erro": "Nao foi possivel conectar ao banco"}), 500

    try:
        with conexao.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) as total_usuarios FROM usuarios")
            total_usuarios = cursor.fetchone()['total_usuarios']

            cursor.execute("SELECT COUNT(*) as total_eventos FROM eventos_passagem")
            total_eventos = cursor.fetchone()['total_eventos']

            cursor.execute("SELECT COUNT(*) as total_agendamentos FROM agendamentos")
            total_agendamentos = cursor.fetchone()['total_agendamentos']

            cursor.execute("SELECT COUNT(*) as qtd FROM usuarios WHERE tipo_perfil = 1")
            qtd_trilheiros = cursor.fetchone()['qtd']

            cursor.execute("SELECT COUNT(*) as qtd FROM usuarios WHERE tipo_perfil = 2")
            qtd_guias = cursor.fetchone()['qtd'] 

            cursor.execute("SELECT COUNT(*) as qtd FROM usuarios WHERE tipo_perfil = 3")
            qtd_admins = cursor.fetchone()['qtd']

            cursor.execute("SELECT COUNT(*) as qtd FROM agendamentos WHERE status = 'confirmado'")
            qtd_agendamentos_confirmados = cursor.fetchone()['qtd']

            cursor.execute("SELECT COUNT(*) as qtd FROM agendamentos WHERE status = 'pendente'")
            qtd_agendamentos_pendentes = cursor.fetchone()['qtd']

            cursor.execute("SELECT timestamp_leitura FROM eventos_passagem ORDER BY timestamp_leitura DESC LIMIT 1")
            ultimo_evento = cursor.fetchone()
            ultimo_evento_data = ultimo_evento['timestamp_leitura'] if ultimo_evento else None

        return jsonify({
            "total_usuarios": total_usuarios,
            "total_eventos_passagem": total_eventos,
            "total_agendamentos": total_agendamentos,
            
            "qtd_trilheiros": qtd_trilheiros,
            "qtd_operadores": qtd_guias,
            "qtd_admins": qtd_admins,

            "agendamentos_confirmados": qtd_agendamentos_confirmados,
            "agendamentos_pendentes": qtd_agendamentos_pendentes,
            
            "ultimo_evento_data": ultimo_evento_data
        })

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao: conexao.close()

    # 19 NOVO ENDPOINT: Listar Usuários (Com Filtro Opcional) ---
@app.route('/api/usuarios', methods=['GET'])
def get_usuarios():
    filtro_tipo = request.args.get('tipo_perfil')
    
    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500

    try:
        with conexao.cursor() as cursor:
            sql = """
            SELECT id, nome, email, tipo_perfil, telefone, idade, sexo, url_foto_perfil, status_guia 
            FROM usuarios
            """
            
            if filtro_tipo:
                sql += f" WHERE tipo_perfil = {int(filtro_tipo)}"
            
            sql += " ORDER BY nome ASC"
            
            cursor.execute(sql)
            usuarios = cursor.fetchall()
            return jsonify(usuarios)
            
    except pymysql.Error as err:
        return jsonify({"erro": str(err)}), 500
    finally:
        if conexao: conexao.close()

# --- ENDPOINT 20: Buscar Dados Completos do Usuário (GET) ---
@app.route('/api/usuario/<int:user_id>', methods=['GET'])
def get_dados_usuario_completo(user_id):
    print(f"[API_SERVER] Buscando dados completos para ID: {user_id}")
    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500

    try:
        with conexao.cursor() as cursor:
            sql = """
            SELECT id, nome, email, telefone, idade, sexo, url_foto_perfil, tipo_perfil, status_guia
            FROM usuarios WHERE id = %s
            """
            cursor.execute(sql, (user_id,))
            usuario = cursor.fetchone()

            if not usuario:
                return jsonify({"erro": "Usuário não encontrado"}), 404

            return jsonify(usuario)

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro SQL: {err}"}), 500
    finally:
        if conexao: conexao.close()

# --- ENDPOINT 21: Atualizar Dados do Usuário (PUT) ---
@app.route('/api/usuario/<int:user_id>/dados', methods=['PUT'])
def atualizar_dados_usuario(user_id):
    print(f"[API_SERVER] Atualizando dados para ID: {user_id}")
    data = request.json
    
    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500

    try:
        campos = []
        valores = []

        if 'nome' in data:
            campos.append("nome = %s")
            valores.append(data['nome'])
        
        if 'telefone' in data:
            campos.append("telefone = %s")
            valores.append(data['telefone'])
            
        if 'idade' in data:
            campos.append("idade = %s")
            valores.append(data['idade'])
            
        if 'sexo' in data:
            campos.append("sexo = %s")
            valores.append(data['sexo'])

        if 'senha' in data and data['senha']:
            campos.append("senha_hash = %s")
            valores.append(generate_password_hash(data['senha']))

        if not campos:
            return jsonify({"mensagem": "Nenhum dado enviado para atualização"}), 200


        valores.append(user_id) 

        
        sql = f"UPDATE usuarios SET {', '.join(campos)} WHERE id = %s"
        
        with conexao.cursor() as cursor:
            cursor.execute(sql, tuple(valores))
            conexao.commit()
            
        return jsonify({"mensagem": "Dados atualizados com sucesso!"})

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro SQL: {err}"}), 500
    finally:
        if conexao:
            conexao.close()

# --- Recuperar Senha (Esqueci minha senha) ---
@app.route('/api/recuperar-senha', methods=['POST'])
def recuperar_senha():
    print("[API_SERVER] Recebida solicitação de recuperação de senha")
    data = request.json
    email = data.get('email')
    nova_senha = data.get('nova_senha')

    if not email or not nova_senha:
        return jsonify({"erro": "E-mail e nova senha são obrigatórios"}), 400

    conexao = conectar_mysql()
    if conexao is None:
        return jsonify({"erro": "Sem conexão com BD"}), 500

    try:
        with conexao.cursor() as cursor:
            cursor.execute("SELECT id FROM usuarios WHERE email = %s", (email,))
            usuario = cursor.fetchone()

            if not usuario:
                return jsonify({"erro": "E-mail não encontrado"}), 404

            nova_hash = generate_password_hash(nova_senha)
            cursor.execute(
                "UPDATE usuarios SET senha_hash = %s WHERE id = %s",
                (nova_hash, usuario['id'])
            )
            conexao.commit()

        return jsonify({"mensagem": "Senha redefinida com sucesso!"})

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao:
            conexao.close()
        
       # --- ENDPOINT 22: Listar Agendamentos Pendentes (CORRIGIDO) ---
@app.route('/api/agendamentos/pendentes', methods=['GET'])
def get_agendamentos_pendentes():
    print("[API_SERVER] Buscando agendamentos sem guia...")
    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500

    try:
        with conexao.cursor() as cursor:
            sql = """
            SELECT 
                a.id, 
                a.data_agendada, 
                a.status, 
                t.nome as nome_trilha,       -- Pega da tabela trilhas (t)
                t.dificuldade,               -- Pega da tabela trilhas (t)
                t.duracao_estimada as duracao_estimada_min,
                t.notas,
                u.nome as nome_trilheiro,    -- Pega do usuario (u)
                u.url_foto_perfil as foto_trilheiro
            FROM agendamentos a
            JOIN trilhas t ON a.trilha_id = t.id        -- Conecta agendamento com trilha
            JOIN usuarios u ON t.id_usuario_lider = u.id -- Conecta trilha com o dono (trilheiro)
            WHERE a.id_guia IS NULL AND a.status = 'pendente'
            ORDER BY a.data_agendada ASC
            """
            cursor.execute(sql)
            pendentes = cursor.fetchall()
            
            for ag in pendentes:
                if ag['data_agendada']:
                    ag['data_agendada'] = ag['data_agendada'].strftime('%Y-%m-%d %H:%M:%S')

            return jsonify(pendentes)
    except pymysql.Error as err:
        print(f"[API_SERVER] Erro SQL detalhado: {err}") 
        return jsonify({"erro": str(err)}), 500
    finally:
        if conexao: conexao.close()
        
        # --- ENDPOINT 23: Atribuir Guia a um Agendamento ---
@app.route('/api/agendamento/<int:agendamento_id>/atribuir', methods=['PUT'])
def atribuir_guia(agendamento_id):
    data = request.json
    id_guia = data.get('id_guia') 

    if not id_guia:
        return jsonify({"erro": "ID do guia é obrigatório"}), 400

    print(f"[API_SERVER] Atribuindo agendamento {agendamento_id} ao guia {id_guia}")
    
    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500

    try:
        with conexao.cursor() as cursor:
            sql = "UPDATE agendamentos SET id_guia = %s WHERE id = %s"
            cursor.execute(sql, (id_guia, agendamento_id))
            conexao.commit()
            
            return jsonify({"mensagem": "Guia atribuído com sucesso!"})
    except pymysql.Error as err:
        return jsonify({"erro": str(err)}), 500
    finally:
        if conexao: conexao.close()
        
        # --- ENDPOINT 24: Atualizar Status do Agendamento ---
@app.route('/api/agendamento/<int:agendamento_id>/status', methods=['PUT'])
def atualizar_status_agendamento(agendamento_id):
    data = request.json
    novo_status = data.get('status') 

    if not novo_status:
        return jsonify({"erro": "Status é obrigatório"}), 400

    print(f"[API_SERVER] Atualizando agendamento {agendamento_id} para status: {novo_status}")

    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500

    try:
        with conexao.cursor() as cursor:
            sql = "UPDATE agendamentos SET status = %s WHERE id = %s"
            cursor.execute(sql, (novo_status, agendamento_id))
            conexao.commit()
            
            return jsonify({"mensagem": f"Status atualizado para {novo_status}"})
    except pymysql.Error as err:
        return jsonify({"erro": str(err)}), 500
    finally:
        if conexao: conexao.close()

# --- ENDPOINT 25: Buscar Usuário por CPF ---
@app.route('/api/usuario/buscar-cpf/<string:cpf>', methods=['GET'])
def buscar_usuario_por_cpf(cpf):
    cpf_limpo = ''.join(filter(str.isdigit, cpf))
    if len(cpf_limpo) != 11:
        return jsonify({"erro": "CPF inválido"}), 400

    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500

    try:
        with conexao.cursor() as cursor:
            cursor.execute(
                "SELECT id, nome, email, tipo_perfil, telefone, url_foto_perfil FROM usuarios WHERE cpf = %s",
                (cpf_limpo,)
            )
            usuario = cursor.fetchone()
            if not usuario:
                return jsonify({"erro": "Usuário não encontrado"}), 404
            return jsonify(usuario)
    except pymysql.Error as err:
        return jsonify({"erro": str(err)}), 500
    finally:
        if conexao: conexao.close()

# --- ENDPOINT 26: Atualizar Tipo de Perfil do Usuário ---
@app.route('/api/usuario/<int:user_id>/perfil', methods=['PUT'])
def atualizar_perfil_usuario(user_id):
    data = request.json
    novo_tipo = data.get('tipo_perfil')

    if novo_tipo not in [1, 2, 3]:
        return jsonify({"erro": "tipo_perfil inválido. Use 1 (Trilheiro), 2 (Guia) ou 3 (Operador)"}), 400

    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Sem conexão"}), 500

    try:
        with conexao.cursor() as cursor:
            cursor.execute(
                "UPDATE usuarios SET tipo_perfil = %s WHERE id = %s",
                (novo_tipo, user_id)
            )
            conexao.commit()
            if cursor.rowcount == 0:
                return jsonify({"erro": "Usuário não encontrado"}), 404
            return jsonify({"mensagem": "Perfil atualizado com sucesso!"})
    except pymysql.Error as err:
        return jsonify({"erro": str(err)}), 500
    finally:
        if conexao: conexao.close()

# --- Roda o Servidor ---
if __name__ == '__main__':
    print("[API_SERVER] Iniciando servidor Flask...")
    # host='0.0.0.0' faz o servidor ser visível na sua rede local (pelo IP 192.168.15.79)
    # e também em localhost (127.0.0.1)
    app.run(host='0.0.0.0', port=5000, debug=True)

