from fastapi import FastAPI, Depends
from pydantic import BaseModel
from typing import List
from sqlalchemy.orm import Session
from database import init_db, SessionLocal, Project, ClassRoom, Student
from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, Depends, File, UploadFile # Thêm File, UploadFile
from fastapi.staticfiles import StaticFiles # Thêm thư viện cấp quyền xem ảnh
import os
import shutil

# Khởi tạo ứng dụng
app = FastAPI(title="SAMS Backend API")
# Tạo thư mục chứa ảnh nếu chưa có
os.makedirs("static/avatars", exist_ok=True)

# Cấp quyền truy cập công khai cho thư mục static
app.mount("/static", StaticFiles(directory="static"), name="static")

# CẤP QUYỀN CORS: Bắt buộc phải có để App Flutter không bị chặn khi gửi dữ liệu sang
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Tự động tạo bảng nếu chưa có
init_db()


# Hàm mở kết nối an toàn tới MySQL
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# =====================================================================
# 1. ĐỊNH NGHĨA CẤU TRÚC DỮ LIỆU SẼ NHẬN TỪ FLUTTER (Pydantic Models)
# =====================================================================
class StudentCreate(BaseModel):
    stt: str
    name: str
    gender: str
    dob: str
    hometown: str
    phone: str
    username: str
    password: str


class ClassCreate(BaseModel):
    class_name: str
    students: List[StudentCreate] = []
    timetable: list = []


class ProjectCreate(BaseModel):
    project_name: str
    school_name: str
    academic_year: str
    project_type: str
    session_type: str
    attendance_mode: str
    global_rule: str
    classes: List[ClassCreate] = []
    user_id: int


# =====================================================================
# 2. XÂY DỰNG API NHẬN DỮ LIỆU VÀ LƯU VÀO MYSQL (Xử lý hàng loạt)
# =====================================================================
@app.post("/api/create-project")
def create_project(project_data: ProjectCreate, db: Session = Depends(get_db)):
    try:
        # BƯỚC 1: Lưu thông tin Dự Án
        new_project = Project(
            project_name=project_data.project_name,
            school_name=project_data.school_name,
            academic_year=project_data.academic_year,
            project_type=project_data.project_type,
            session_type=project_data.session_type,
            attendance_mode=project_data.attendance_mode,
            global_rule=project_data.global_rule
        )
        db.add(new_project)
        db.commit()
        db.refresh(new_project)

        # BƯỚC 2: GHI DANH SUPER ADMIN NGAY SAU KHI TẠO DỰ ÁN (ĐÃ ĐƯA RA NGOÀI VÒNG LẶP)
        from database import ProjectMember
        owner = ProjectMember(
            project_id=new_project.id,
            user_id=project_data.user_id,  # Lấy ID người dùng gửi lên
            role="Super Admin",
            status="Hoạt động"
        )
        db.add(owner)
        db.commit()

        # BƯỚC 3: Lưu các Lớp học vào bảng `classes`
        for cls_data in project_data.classes:
            new_class = ClassRoom(
                project_id=new_project.id,
                class_name=cls_data.class_name,
                timetable=cls_data.timetable
            )
            db.add(new_class)
            db.commit()
            db.refresh(new_class)

            for std_data in cls_data.students:
                new_student = Student(
                    class_id=new_class.id,
                    student_code=std_data.stt,
                    full_name=std_data.name,
                    gender=std_data.gender,
                    dob=std_data.dob,
                    hometown=std_data.hometown,
                    phone=std_data.phone,
                    username=std_data.username,
                    password=std_data.password
                )
                db.add(new_student)
            db.commit()

        return {
            "status": "success",
            "message": "Tuyệt vời! Đã lưu Dự án, Lớp học và nạp toàn bộ danh sách Excel vào MySQL!",
            "project_id": new_project.id
        }

    except Exception as e:
        db.rollback()
        return {"status": "error", "message": f"Lỗi hệ thống: {str(e)}"}


# =====================================================================
# 4. API ĐĂNG KÝ TÀI KHOẢN QUẢN TRỊ (REGISTER)
# =====================================================================

class UserRegister(BaseModel):
    full_name: str
    email: str
    phone: str
    password: str
    role: str


@app.post("/api/register")
def register_user(user_data: UserRegister, db: Session = Depends(get_db)):
    from database import Staff

    try:
        # 1. Kiểm tra xem Email đã tồn tại chưa
        existing_user = db.query(Staff).filter(Staff.email == user_data.email).first()
        if existing_user:
            return {"status": "error", "message": "Email này đã được đăng ký trong hệ thống!"}

        # 2. Tạo tài khoản mới (KHÔNG CẦN DUYỆT GÌ CẢ)
        new_user = Staff(
            full_name=user_data.full_name,
            email=user_data.email,
            phone=user_data.phone,
            password=user_data.password,
            role=user_data.role,
            username=user_data.email  # Lấy email làm username đăng nhập luôn cho tiện
        )

        db.add(new_user)
        db.commit()

        return {"status": "success", "message": "Tuyệt vời! Đăng ký tài khoản thành công."}

    except Exception as e:
        db.rollback()
        return {"status": "error", "message": f"Lỗi Server: {str(e)}"}


# =====================================================================
# 5. API ĐĂNG NHẬP (LOGIN)
# =====================================================================

class UserLogin(BaseModel):
    username: str  # Có thể là Email hoặc Tên đăng nhập
    password: str
    role: str


@app.post("/api/login")
def login_user(login_data: UserLogin, db: Session = Depends(get_db)):
    from database import Staff

    try:
        # 1. Tìm user trong Database theo Email (hoặc username) và Quyền truy cập
        user = db.query(Staff).filter(
            (Staff.email == login_data.username) | (Staff.username == login_data.username),
            Staff.role == login_data.role
        ).first()

        # 2. Chốt chặn 1: Không tìm thấy tài khoản hoặc chọn sai quyền
        if not user:
            return {"status": "error",
                    "message": f"Tài khoản không tồn tại hoặc bạn không có quyền '{login_data.role}'!"}

        # 3. Chốt chặn 2: Sai mật khẩu
        if user.password != login_data.password:
            return {"status": "error", "message": "Mật khẩu không chính xác. Vui lòng thử lại!"}

        # 4. THÀNH CÔNG: Trả về thông tin User để Flutter lưu lại (Làm phiên đăng nhập)
        return {
            "status": "success",
            "message": f"Đăng nhập thành công! Chào mừng {user.full_name}.",
            "data": {
                "user_id": user.id,
                "full_name": user.full_name,
                "role": user.role,

                # BỔ SUNG 4 DÒNG NÀY ĐỂ FLUTTER BIẾT MÀ HIỂN THỊ
                "setting_language": user.setting_language or "Tiếng Việt",
                "setting_timezone": user.setting_timezone or "UTC +07:00 (Hồ Chí Minh)",
                "setting_theme_color": user.setting_theme_color or "0xFF448AFF",
                "setting_font_scale": user.setting_font_scale if user.setting_font_scale is not None else 2.0
            }
        }

    except Exception as e:
        return {"status": "error", "message": f"Lỗi Server: {str(e)}"}

# =====================================================================
# API CHO QUẢN LÝ TÀI KHOẢN (ACCOUNT SETTINGS)
# =====================================================================
# =====================================================================
# API CHO QUẢN LÝ TÀI KHOẢN (ACCOUNT SETTINGS)
# =====================================================================
class UserUpdate(BaseModel):
    full_name: str
    dob: str
    hometown: str
    current_address: str
    religion: str
    email: str
    phone: str
    facebook: str
    position: str = ""  # Từ khóa chuẩn xác cho Chức vụ
    degree: str = ""  # Từ khóa chuẩn xác cho Bằng cấp
    graduated_from: str = ""
    dynamic_1: str
    dynamic_2: str
    dynamic_3: str


# 1. Cổng lấy thông tin (GET)
@app.get("/api/users/{user_id}")
def get_user_profile(user_id: int, db: Session = Depends(get_db)):
    from database import Staff

    user = db.query(Staff).filter(Staff.id == user_id).first()
    if not user:
        return {"status": "error", "message": "Không tìm thấy người dùng trong hệ thống!"}

    return {
        "status": "success",
        "data": {
            "avatar_url": user.avatar_url or "",
            "full_name": user.full_name or "",
            "dob": user.dob or "",
            "hometown": user.hometown or "",
            "current_address": user.current_address or "",
            "religion": user.religion or "",
            "email": user.email or "",
            "phone": user.phone or "",
            "facebook": user.facebook or "",

            # ĐỔI: Trả về cả Role (Quyền) và Position (Chức vụ)
            "role": user.role or "",
            "position": user.position or "",

            "degree": user.degree or "",
            "graduated_from": user.graduated_from or "",
            "dynamic_1": user.dynamic_1 or "",
            "dynamic_2": user.dynamic_2 or "",
            "dynamic_3": user.dynamic_3 or ""
        }
    }


# 2. Cổng lưu thông tin (PUT)
@app.put("/api/users/{user_id}")
def update_user_profile(user_id: int, user_data: UserUpdate, db: Session = Depends(get_db)):
    from database import Staff
    user = db.query(Staff).filter(Staff.id == user_id).first()
    if not user:
        return {"status": "error", "message": "Không tìm thấy tài khoản"}

    try:
        user.full_name = user_data.full_name
        user.dob = user_data.dob
        user.hometown = user_data.hometown
        user.current_address = user_data.current_address
        user.religion = user_data.religion

        user.email = user_data.email
        user.username = user_data.email

        user.phone = user_data.phone
        user.facebook = user_data.facebook

        # ĐỔI: Lưu Chức vụ công tác vào cột 'position', KHÔNG CHẠM VÀO 'role'
        user.position = user_data.position

        user.degree = user_data.degree
        user.graduated_from = user_data.graduated_from
        user.dynamic_1 = user_data.dynamic_1
        user.dynamic_2 = user_data.dynamic_2
        user.dynamic_3 = user_data.dynamic_3
        db.commit()
        return {"status": "success", "message": "Đã lưu thành công!"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": str(e)}

# =====================================================================
# API UPLOAD ẢNH ĐẠI DIỆN
# =====================================================================
@app.post("/api/users/{user_id}/avatar")
def upload_avatar(user_id: int, file: UploadFile = File(...), db: Session = Depends(get_db)):
    from database import Staff
    user = db.query(Staff).filter(Staff.id == user_id).first()
    if not user:
        return {"status": "error", "message": "Không tìm thấy tài khoản"}

    try:
        # Tạo đường dẫn lưu file: Ví dụ -> static/avatars/1_hinhanh.jpg
        file_location = f"static/avatars/{user_id}_{file.filename}"

        # Lưu file vật lý vào ổ cứng Server
        with open(file_location, "wb+") as file_object:
            shutil.copyfileobj(file.file, file_object)

        # Cập nhật đường dẫn vào Database
        user.avatar_url = f"/{file_location}"
        db.commit()

        return {"status": "success", "message": "Cập nhật ảnh thành công!", "avatar_url": user.avatar_url}
    except Exception as e:
        return {"status": "error", "message": f"Lỗi lưu ảnh: {str(e)}"}


# =====================================================================
# API CÀI ĐẶT HỆ THỐNG (LƯU CẤU HÌNH & ĐỔI MẬT KHẨU)
# =====================================================================

class SettingsUpdate(BaseModel):
    language: str
    timezone: str
    theme_color: str
    font_scale: float


class PasswordUpdate(BaseModel):
    old_password: str
    new_password: str


# 1. API Lưu cài đặt giao diện
@app.put("/api/users/{user_id}/settings")
def update_user_settings(user_id: int, settings: SettingsUpdate, db: Session = Depends(get_db)):
    from database import Staff
    user = db.query(Staff).filter(Staff.id == user_id).first()
    if not user:
        return {"status": "error", "message": "Không tìm thấy tài khoản"}

    try:
        user.setting_language = settings.language
        user.setting_timezone = settings.timezone
        user.setting_theme_color = settings.theme_color
        user.setting_font_scale = settings.font_scale
        db.commit()
        return {"status": "success", "message": "Đã lưu cài đặt hệ thống!"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": str(e)}


# 2. API Đổi mật khẩu
@app.put("/api/users/{user_id}/password")
def change_user_password(user_id: int, pass_data: PasswordUpdate, db: Session = Depends(get_db)):
    from database import Staff
    user = db.query(Staff).filter(Staff.id == user_id).first()
    if not user:
        return {"status": "error", "message": "Không tìm thấy tài khoản"}

    try:
        # Kiểm tra mật khẩu cũ có đúng không
        if user.password != pass_data.old_password:
            return {"status": "error", "message": "Mật khẩu hiện tại không chính xác!"}

        # Lưu mật khẩu mới
        user.password = pass_data.new_password
        db.commit()
        return {"status": "success", "message": "Cập nhật mật khẩu thành công!"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": str(e)}


# =====================================================================
# API LẤY DANH SÁCH DỰ ÁN ĐỂ HIỂN THỊ LÊN KHO
# =====================================================================
@app.get("/api/projects")
def get_all_projects(db: Session = Depends(get_db)):
    from database import Project
    # Lấy toàn bộ dự án từ Database
    projects = db.query(Project).all()

    data = []
    for p in projects:
        data.append({
            "id": p.id,
            "project_name": p.project_name,
            "project_type": p.project_type,
            "project_code": p.project_code,
            "status": "Hoạt động"  # Mặc định dự án mới tạo là Hoạt động
        })

    return {"status": "success", "data": data}


# =====================================================================
# API LẤY CHI TIẾT 1 DỰ ÁN
# =====================================================================
@app.get("/api/projects/{project_id}")
def get_project_detail(project_id: int, db: Session = Depends(get_db)):
    from database import Project, ClassRoom, Student, ProjectMember  # ---> KHAI BÁO THÊM ProjectMember
    project = db.query(Project).filter(Project.id == project_id).first()

    if not project:
        return {"status": "error", "message": "Không tìm thấy dự án"}

    # Đếm số lượng học sinh thực tế
    total_students = db.query(Student).join(ClassRoom).filter(ClassRoom.project_id == project_id).count()

    # ---> BỔ SUNG: ĐẾM TỔNG NHÂN SỰ (Những người có trạng thái Hoạt động)
    total_staff = db.query(ProjectMember).filter(
        ProjectMember.project_id == project_id,
        ProjectMember.status == "Hoạt động"
    ).count()

    return {
        "status": "success",
        "data": {
            "project_name": project.project_name or "",
            "school_name": project.school_name or "",
            "academic_year": project.academic_year or "",
            "session_type": project.session_type or "",
            "attendance_mode": project.attendance_mode or "",
            "global_rule": project.global_rule or "",
            "project_code": project.project_code or "",
            "morning_time": project.morning_time or "",
            "afternoon_time": project.afternoon_time or "",

            # TRẢ VỀ CÁC CHỈ SỐ THỐNG KÊ THẬT
            "total_students": total_students,
            "total_staff": total_staff,  # ---> ĐÃ THAY SỐ 0 THÀNH BIẾN ĐẾM THẬT
            "late_rate": "0.0%",
            "absent_rate": "0.0%",

            "chart_data": [
                {'day': 'T2', 'ok': 0, 'late': 0}, {'day': 'T3', 'ok': 0, 'late': 0},
                {'day': 'T4', 'ok': 0, 'late': 0}, {'day': 'T5', 'ok': 0, 'late': 0},
                {'day': 'T6', 'ok': 0, 'late': 0}, {'day': 'T7', 'ok': 0, 'late': 0}
            ]
        }
    }


# =====================================================================
# API CẬP NHẬT CẤU HÌNH DỰ ÁN
# =====================================================================
class ProjectUpdate(BaseModel):
    project_name: str
    school_name: str
    academic_year: str
    session_type: str
    attendance_mode: str
    global_rule: str
    morning_time: str  # ---> BỔ SUNG
    afternoon_time: str


@app.put("/api/projects/{project_id}")
def update_project_detail(project_id: int, project_data: ProjectUpdate, db: Session = Depends(get_db)):
    from database import Project
    project = db.query(Project).filter(Project.id == project_id).first()

    if not project:
        return {"status": "error", "message": "Không tìm thấy dự án!"}

    try:
        # Cập nhật tất cả thông tin (Trừ project_type là không đổi)
        project.project_name = project_data.project_name
        project.school_name = project_data.school_name
        project.academic_year = project_data.academic_year
        project.session_type = project_data.session_type
        project.attendance_mode = project_data.attendance_mode
        project.global_rule = project_data.global_rule
        project.morning_time = project_data.morning_time
        project.afternoon_time = project_data.afternoon_time
        db.commit()
        return {"status": "success", "message": "Lưu cấu hình thành công!"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": str(e)}


# =====================================================================
# API LẤY CHI TIẾT 1 LỚP HỌC (KÈM HỌC SINH VÀ THỜI KHÓA BIỂU)
# =====================================================================
@app.get("/api/classes/{class_id}")
def get_class_detail(class_id: int, db: Session = Depends(get_db)):
    from database import ClassRoom, Student, Staff
    classroom = db.query(ClassRoom).filter(ClassRoom.id == class_id).first()
    if not classroom:
        return {"status": "error", "message": "Không tìm thấy lớp học"}

    # Lấy thông tin GVCN (Nếu có)
    teacher = db.query(Staff).filter(Staff.id == classroom.teacher_id).first() if classroom.teacher_id else None

    # Lấy danh sách Học sinh
    students = db.query(Student).filter(Student.class_id == class_id).all()
    student_list = []

    # Khuôn điểm danh mặc định nếu học sinh chưa có dữ liệu
    default_attendance = {
        f"{classroom.current_year_start}-{classroom.current_year_end}": {
            classroom.current_semester: {"lateCount": 0, "absentCount": 0, "excusedCount": 0, "history": []}
        }
    }

    for st in students:
        student_list.append({
            "id": st.student_code or "Chưa cấp",
            "name": st.full_name or "Không tên",
            "gender": st.gender or "Nam",
            "dob": st.dob or "Chưa cập nhật",
            "parent": st.parent_name or "Chưa cập nhật",
            "phone": st.phone or "Chưa cập nhật",
            "email": st.email or "hs@edu.vn",
            "avatar_url": st.avatar_url or "",
            "attendance": st.attendance_data or default_attendance
        })

    # Đóng gói thông tin GVCN
    teacher_info = {}
    if teacher:
        teacher_info = {
            "avatar_url": teacher.avatar_url or "",
            "name": teacher.full_name,
            "email": teacher.email,
            "role": "Giáo viên chủ nhiệm",
            "dob": teacher.dob,
            "phone": teacher.phone,
            "hometown": teacher.hometown,
            "religion": teacher.religion,
            "current_address": teacher.current_address,
            "position": teacher.position,
            "degree": teacher.degree,
            "school": teacher.graduated_from,
            "dynamic_1": teacher.dynamic_1 or "",
            "dynamic_2": teacher.dynamic_2 or "",
            "dynamic_3": teacher.dynamic_3 or ""
        }
    else:
        # Nếu chưa phân công thì chỉ trả về tên để Flutter nhận diện
        teacher_info = {"name": "Chưa phân công"}

    return {
        "status": "success",
        "data": {
            "class_name": classroom.class_name,
            "course_start_year": classroom.course_start_year,
            "course_end_year": classroom.course_end_year,
            "current_year_start": classroom.current_year_start,
            "current_year_end": classroom.current_year_end,
            "current_semester": classroom.current_semester,
            "timetable": classroom.timetable or [],  # Trả về list rỗng nếu chưa có TKB
            "teacher": teacher_info,
            "students": student_list
        }
    }


# =====================================================================
# API LẤY DANH SÁCH LỚP HỌC THEO DỰ ÁN (HIỂN THỊ MENU)
# =====================================================================
@app.get("/api/projects/{project_id}/classes")
def get_project_classes(project_id: int, db: Session = Depends(get_db)):
    from database import ClassRoom
    # Tìm tất cả các lớp có project_id trùng khớp
    classes = db.query(ClassRoom).filter(ClassRoom.project_id == project_id).all()

    data = []
    for c in classes:
        data.append({
            "id": c.id,
            "class_name": c.class_name
        })

    return {"status": "success", "data": data}


# =====================================================================
# API CẬP NHẬT CẤU HÌNH LỚP VÀ THỜI KHÓA BIỂU
# =====================================================================
class ClassUpdate(BaseModel):
    class_name: str
    course_start_year: int
    course_end_year: int
    current_year_start: int
    current_year_end: int
    current_semester: str
    timetable: list


@app.put("/api/classes/{class_id}")
def update_class_detail(class_id: int, class_data: ClassUpdate, db: Session = Depends(get_db)):
    from database import ClassRoom
    classroom = db.query(ClassRoom).filter(ClassRoom.id == class_id).first()
    if not classroom:
        return {"status": "error", "message": "Không tìm thấy lớp học"}

    try:
        classroom.class_name = class_data.class_name
        classroom.course_start_year = class_data.course_start_year
        classroom.course_end_year = class_data.course_end_year
        classroom.current_year_start = class_data.current_year_start
        classroom.current_year_end = class_data.current_year_end
        classroom.current_semester = class_data.current_semester
        classroom.timetable = class_data.timetable  # Lưu thời khóa biểu mới
        db.commit()
        return {"status": "success"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": str(e)}


# =====================================================================
# API THAM GIA DỰ ÁN BẰNG MÁ
# =====================================================================
class JoinProjectRequest(BaseModel):
    project_code: str
    user_id: int


@app.post("/api/projects/join")
def join_project(request: JoinProjectRequest, db: Session = Depends(get_db)):
    from database import Project, ProjectMember
    project = db.query(Project).filter(Project.project_code == request.project_code).first()

    if not project:
        return {"status": "error", "message": "Mã dự án không tồn tại!"}

    existing = db.query(ProjectMember).filter(ProjectMember.project_id == project.id, ProjectMember.user_id == request.user_id).first()
    if existing:
        return {"status": "error", "message": "Bạn đã gửi yêu cầu gia nhập dự án này rồi!"}

    new_member = ProjectMember(project_id=project.id, user_id=request.user_id, role="Khách truy cập", status="Đang xét duyệt")
    db.add(new_member)
    db.commit()
    return {
        "status": "success",
        "message": "Đã gửi yêu cầu. Vui lòng chờ Quản trị viên duyệt!",
        "data": {
            "id": project.id, "project_name": project.project_name, "project_type": project.project_type,
            "role": "Khách truy cập", "status": "Đang xét duyệt", "is_owner": False
        }
    }

# =====================================================================
# 2. API KÉO DANH SÁCH DỰ ÁN (CỦA MÌNH + DỰ ÁN XIN GIA NHẬP)
# =====================================================================
@app.get("/api/users/{user_id}/projects")
def get_user_projects(user_id: int, db: Session = Depends(get_db)):
    from database import Project, ProjectMember
    memberships = db.query(ProjectMember).filter(ProjectMember.user_id == user_id).all()

    data = []
    for m in memberships:
        p = db.query(Project).filter(Project.id == m.project_id).first()
        if p:
            data.append({
                "id": p.id, "project_name": p.project_name, "project_type": p.project_type,
                "role": m.role, "status": m.status, "is_owner": m.role == "Super Admin"
            })
    return {"status": "success", "data": data}

# =====================================================================
# API QUẢN LÝ THÀNH VIÊN DỰ ÁN (XÉT DUYỆT, CẤP QUYỀN, XÓA)
# =====================================================================
from typing import Optional

@app.get("/api/projects/{project_id}/members")
def get_project_members(project_id: int, db: Session = Depends(get_db)):
    from database import ProjectMember, Staff # ---> ĐÃ FIX THÀNH STAFF
    members = db.query(ProjectMember).filter(ProjectMember.project_id == project_id).all()

    active_admins = []
    active_managers = []
    pending_requests = []

    for m in members:
        user = db.query(Staff).filter(Staff.id == m.user_id).first() # ---> ĐÃ FIX THÀNH STAFF
        if not user: continue

        member_data = {
            "id": m.id,
            "user_id": user.id,
            "name": user.full_name,
            "email": user.email,
            "role": m.role,
            "unit": m.unit,
            "status": m.status,

            # ---> BỔ SUNG LẤY THÊM THÔNG TIN CÁ NHÂN TỪ BẢNG STAFF:
            "avatar_url": user.avatar_url or "",
            "dob": user.dob,
            "phone": user.phone,
            "hometown": user.hometown,
            "current_address": user.current_address,
            "religion": user.religion,
            "facebook": user.facebook,
            "position": user.position,
            "degree": user.degree,
            "school": user.graduated_from,
            "dynamic_1": user.dynamic_1 or "",
            "dynamic_2": user.dynamic_2 or "",
            "dynamic_3": user.dynamic_3 or ""
        }
        if m.status == "Đang xét duyệt":
            pending_requests.append(member_data)
        elif m.status == "Hoạt động":
            if m.role == "Super Admin" or m.role == "Admin": active_admins.append(member_data)
            else: active_managers.append(member_data)

    return {"status": "success", "data": {"admins": active_admins, "managers": active_managers, "pending": pending_requests}}

class MemberUpdateRequest(BaseModel):
    status: str
    role: str
    unit: Optional[str] = None


# 1. API Kéo danh sách thành viên trong dự án
def get_user_projects(user_id: int, db: Session = Depends(get_db)):
    from database import Project, ProjectMember
    memberships = db.query(ProjectMember).filter(ProjectMember.user_id == user_id).all()

    data = []
    for m in memberships:
        p = db.query(Project).filter(Project.id == m.project_id).first()
        if p:
            data.append({
                "id": p.id,
                "project_name": p.project_name,
                "project_type": p.project_type,
                "role": m.role,
                "status": m.status,
                "is_owner": m.role == "Super Admin"
            })

    return {"status": "success", "data": data}



@app.put("/api/members/{member_id}")
def update_project_member(member_id: int, request: MemberUpdateRequest, db: Session = Depends(get_db)):
    from database import ProjectMember, ClassRoom  # ---> KHAI BÁO THÊM BẢNG LỚP HỌC
    member = db.query(ProjectMember).filter(ProjectMember.id == member_id).first()
    if not member: return {"status": "error", "message": "Không tìm thấy thành viên!"}

    member.status = request.status
    member.role = request.role
    member.unit = request.unit

    # ---> LOGIC MỚI: NẾU GÁN LÀM QUẢN LÝ LỚP (UNIT MANAGER) THÌ CHÈN ID VÀO LỚP HỌC ĐÓ
    if request.role == 'Unit Manager' and request.unit:
        # Tìm lớp học trong dự án này có tên khớp với tên lớp vừa gán
        target_class = db.query(ClassRoom).filter(
            ClassRoom.project_id == member.project_id,
            ClassRoom.class_name == request.unit
        ).first()

        if target_class:
            target_class.teacher_id = member.user_id  # Chốt sổ: Gắn ID giáo viên vào lớp!

    db.commit()
    return {"status": "success"}

# 3. API Xóa / Từ chối thành viên
@app.delete("/api/members/{member_id}")
def delete_project_member(member_id: int, db: Session = Depends(get_db)):
    from database import ProjectMember
    member = db.query(ProjectMember).filter(ProjectMember.id == member_id).first()
    if member:
        db.delete(member)
        db.commit()
    return {"status": "success"}


# =====================================================================
# API ĐĂNG KÝ KHUÔN MẶT HỌC SINH (FACE ENROLLMENT)
# =====================================================================
import base64

class FaceRegisterRequest(BaseModel):
    image_base64: str

@app.post("/api/students/{student_code}/register-face")
def register_student_face(student_code: str, request: FaceRegisterRequest, db: Session = Depends(get_db)):
    from database import Student
    
    student = db.query(Student).filter(Student.student_code == student_code).first()
    if not student:
        return {"status": "error", "message": "Không tìm thấy học sinh trong hệ thống!"}
        
    try:
        # Xử lý chuỗi Base64: Ví dụ "data:image/jpeg;base64,..."
        base64_data = request.image_base64
        if "," in base64_data:
            base64_data = base64_data.split(",")[1]
            
        # Giải mã ảnh
        image_bytes = base64.b64decode(base64_data)
        
        # Đường dẫn lưu file vật lý: static/avatars/{student_code}_face.jpg
        os.makedirs("static/avatars", exist_ok=True)
        file_location = f"static/avatars/{student_code}_face.jpg"
        
        # Lưu file nhị phân vào ổ đĩa
        with open(file_location, "wb") as f:
            f.write(image_bytes)
            
        # Cập nhật đường dẫn avatar vào cơ sở dữ liệu
        student.avatar_url = f"/{file_location}"
        
        # Đánh dấu cần huấn luyện lại mô hình AI
        global _ai_needs_retrain
        _ai_needs_retrain = True
        
        db.commit()
        
        return {
            "status": "success",
            "message": "Đã lưu ảnh chân dung đăng ký khuôn mặt học sinh thành công!",
            "avatar_url": student.avatar_url
        }
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": f"Lỗi lưu trữ khuôn mặt: {str(e)}"}


# =====================================================================
# API CẤU HÌNH GIỜ ĐIỂM DANH (CAMERA SETTINGS - ADMIN ONLY)
# =====================================================================
from typing import Optional

class AttendanceConfigUpdate(BaseModel):
    morning_time: str   # "07:30 - 11:30"
    afternoon_time: str # "13:30 - 17:00"

@app.get("/api/projects/{project_id}/attendance-config")
def get_attendance_config(project_id: int, db: Session = Depends(get_db)):
    from database import Project
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        return {"status": "error", "message": "Không tìm thấy dự án"}
    return {
        "status": "success",
        "data": {
            "morning_time": project.morning_time or "07:30 - 11:30",
            "afternoon_time": project.afternoon_time or "13:30 - 17:00",
            "session_type": project.session_type or "Sáng & Chiều",
        }
    }

@app.put("/api/projects/{project_id}/attendance-config")
def update_attendance_config(project_id: int, config: AttendanceConfigUpdate, db: Session = Depends(get_db)):
    from database import Project
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        return {"status": "error", "message": "Không tìm thấy dự án"}
    try:
        project.morning_time = config.morning_time
        project.afternoon_time = config.afternoon_time
        db.commit()
        return {"status": "success", "message": "Đã lưu cấu hình giờ điểm danh thành công!"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": str(e)}


# =====================================================================
# AI ĐỐI KHỚP KHUÔN MẶT THỜI GIAN THỰC (FACE RECOGNITION ATTENDANCE)
# =====================================================================
import cv2
import numpy as np
from datetime import datetime, date, time

# Các biến toàn cục quản lý cache mô hình AI
_face_recognizer = None
_label_to_code = {}
_ai_needs_retrain = True

# Hàm load ảnh và huấn luyện mô hình AI LBPH
def train_face_recognizer(db: Session):
    global _face_recognizer, _label_to_code, _ai_needs_retrain
    from database import Student
    
    print("[AI ENGINE] Đang huấn luyện lại mô hình đối khớp khuôn mặt...")
    
    # Khởi động mô hình nhận diện khuôn mặt LBPH của OpenCV
    recognizer = cv2.face.LBPHFaceRecognizer_create()
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    
    students = db.query(Student).all()
    
    faces = []
    labels = []
    label_to_code = {}
    
    label_id = 1
    for st in students:
        if st.avatar_url:
            img_path = st.avatar_url.lstrip('/')
            if os.path.exists(img_path):
                try:
                    # Đọc ảnh ở chế độ màu xám (Grayscale)
                    img = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)
                    if img is None:
                        continue
                    
                    # Phát hiện khuôn mặt
                    detected_faces = face_cascade.detectMultiScale(img, scaleFactor=1.1, minNeighbors=5, minSize=(50, 50))
                    for (x, y, w, h) in detected_faces:
                        face_roi = img[y:y+h, x:x+w]
                        face_roi = cv2.resize(face_roi, (200, 200))
                        faces.append(face_roi)
                        labels.append(label_id)
                        
                    label_to_code[label_id] = st.student_code
                    label_id += 1
                except Exception as e:
                    print(f"[AI ENGINE] Lỗi huấn luyện học sinh {st.student_code}: {e}")
                    
    if len(faces) > 0:
        recognizer.train(faces, np.array(labels))
        _face_recognizer = recognizer
        _label_to_code = label_to_code
        _ai_needs_retrain = False
        print(f"[AI ENGINE] Đã huấn luyện thành công {len(faces)} khuôn mặt của {len(label_to_code)} học sinh.")
    else:
        _face_recognizer = None
        _label_to_code = {}
        _ai_needs_retrain = False
        print("[AI ENGINE] Không tìm thấy ảnh chân dung học sinh nào hợp lệ để train.")

class FaceRecognizeRequest(BaseModel):
    image_base64: str

@app.post("/api/attendance/recognize-face")
def recognize_face(request: FaceRecognizeRequest, db: Session = Depends(get_db)):
    global _face_recognizer, _label_to_code, _ai_needs_retrain
    from database import Student, AttendanceRecord
    
    # 1. Đảm bảo mô hình được huấn luyện
    if _ai_needs_retrain or _face_recognizer is None:
        try:
            train_face_recognizer(db)
        except Exception as e:
            print(f"[AI ENGINE] Lỗi khi tự động huấn luyện: {e}")
            
    # 2. Giải mã ảnh Base64 gửi lên từ frontend
    try:
        base64_data = request.image_base64
        if "," in base64_data:
            base64_data = base64_data.split(",")[1]
        image_bytes = base64.b64decode(base64_data)
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_GRAYSCALE)
    except Exception as e:
        return {"status": "error", "message": f"Lỗi giải mã ảnh: {e}"}
        
    if img is None:
        return {"status": "error", "message": "Ảnh gửi lên không hợp lệ."}
        
    # 3. Phát hiện khuôn mặt trong frame
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    detected_faces = face_cascade.detectMultiScale(img, scaleFactor=1.1, minNeighbors=5, minSize=(50, 50))
    
    if len(detected_faces) == 0:
        return {"status": "no_face", "message": "Không phát hiện thấy khuôn mặt trong khung hình."}
        
    # Lấy khuôn mặt đầu tiên phát hiện được
    (x, y, w, h) = detected_faces[0]
    face_roi = img[y:y+h, x:x+w]
    face_roi = cv2.resize(face_roi, (200, 200))
    
    # 4. Đối khớp khuôn mặt bằng LBPH
    if _face_recognizer is None:
        return {"status": "unknown", "message": "Hệ thống AI chưa có dữ liệu khuôn mặt đã đăng ký."}
        
    try:
        label, distance = _face_recognizer.predict(face_roi)
        # Tính phần trăm độ tin cậy ngược từ khoảng cách (LBPH distance thường < 80 là khớp tốt)
        confidence_pct = max(0.0, min(100.0, (120.0 - distance) / 120.0 * 100.0))
        
        # Ngưỡng chấp nhận (THRESHOLD = 85.0) -> Khoảng cách khoảng < 85 là khớp
        if distance > 85.0 or label not in _label_to_code:
            return {"status": "unknown", "message": f"Khuôn mặt lạ hoặc không khớp (Độ khớp: {confidence_pct:.1f}%, dist: {distance:.1f})"}
            
        student_code = _label_to_code[label]
        student = db.query(Student).filter(Student.student_code == student_code).first()
        if not student:
            return {"status": "unknown", "message": "Không tìm thấy học sinh liên kết với khuôn mặt này."}
            
        # 5. Ghi nhận điểm danh
        from datetime import timedelta
        today = date.today()
        now_time = datetime.now().time()
        
        # 5.1. Lấy cấu hình ca học từ Project
        classroom = student.classroom
        project = classroom.project if classroom else None
        
        # Thiết lập các mốc mặc định cực chuẩn
        morning_start = time(7, 30, 0)
        morning_end = time(11, 30, 0)
        afternoon_start = time(13, 30, 0)
        afternoon_end = time(17, 0, 0)
        
        session_type = "Sáng & Chiều"
        
        if project:
            if project.session_type:
                session_type = project.session_type
                
            # Đọc morning_time dạng string: "07:30 - 11:30" hoặc "07:30-11:30"
            if project.morning_time and "-" in project.morning_time:
                try:
                    parts = project.morning_time.split("-")
                    sh, sm = map(int, parts[0].strip().split(":"))
                    eh, em = map(int, parts[1].strip().split(":"))
                    morning_start = time(sh, sm, 0)
                    morning_end = time(eh, em, 0)
                except Exception:
                    pass
            
            # Đọc afternoon_time dạng string: "13:30 - 17:00"
            if project.afternoon_time and "-" in project.afternoon_time:
                try:
                    parts = project.afternoon_time.split("-")
                    sh, sm = map(int, parts[0].strip().split(":"))
                    eh, em = map(int, parts[1].strip().split(":"))
                    afternoon_start = time(sh, sm, 0)
                    afternoon_end = time(eh, em, 0)
                except Exception:
                    pass
                    
        # 5.2. Tính midpoint (mốc giữa) để phân chia Đầu/Cuối giờ
        # Ca Sáng midpoint
        m_start_mins = morning_start.hour * 60 + morning_start.minute
        m_end_mins = morning_end.hour * 60 + morning_end.minute
        m_mid_mins = (m_start_mins + m_end_mins) // 2
        morning_midpoint = time(m_mid_mins // 60, m_mid_mins % 60, 0)
        
        # Ca Chiều midpoint
        a_start_mins = afternoon_start.hour * 60 + afternoon_start.minute
        a_end_mins = afternoon_end.hour * 60 + afternoon_end.minute
        a_mid_mins = (a_start_mins + a_end_mins) // 2
        afternoon_midpoint = time(a_mid_mins // 60, a_mid_mins % 60, 0)
        
        # 5.3. Xác định ca/slot hiện tại
        session_type_str = str(session_type or "").strip()
        has_morning = "Sáng" in session_type_str or not session_type_str
        has_afternoon = "Chiều" in session_type_str or not session_type_str
        
        current_slot = None
        is_check_in = True
        target_time = None
        
        if now_time < time(12, 0, 0):
            if has_morning:
                if now_time < morning_midpoint:
                    current_slot = "Đầu giờ Sáng"
                    is_check_in = True
                    target_time = morning_start
                else:
                    current_slot = "Cuối giờ Sáng"
                    is_check_in = False
                    target_time = morning_end
        else:
            if has_afternoon:
                if now_time < afternoon_midpoint:
                    current_slot = "Đầu giờ Chiều"
                    is_check_in = True
                    target_time = afternoon_start
                else:
                    current_slot = "Cuối giờ Chiều"
                    is_check_in = False
                    target_time = afternoon_end
                    
        if not current_slot:
            return {
                "status": "error",
                "message": f"Không có ca học nào hoạt động vào thời gian này ({now_time.strftime('%H:%M')})."
            }
            
        # 5.4. Tính toán trạng thái Đi trễ / Về sớm / Hợp lệ
        dummy_date = date.today()
        dt_now = datetime.combine(dummy_date, now_time)
        dt_target = datetime.combine(dummy_date, target_time)
        
        attendance_status = "Hợp lệ"
        if is_check_in:
            # Check-in: cho phép trễ tối đa 15 phút
            dt_deadline = dt_target + timedelta(minutes=15)
            if dt_now > dt_deadline:
                attendance_status = "Đi trễ"
        else:
            # Check-out: cho phép về sớm tối đa 15 phút
            dt_early_limit = dt_target - timedelta(minutes=15)
            if dt_now < dt_early_limit:
                attendance_status = "Về sớm"
                
        time_str = datetime.now().strftime("%H:%M")
        status_response = "success"
        
        # 5.5. Kiểm tra trùng lặp cho ca học cụ thể này trong ngày
        record = db.query(AttendanceRecord).filter(
            AttendanceRecord.student_id == student.id,
            AttendanceRecord.date == today,
            AttendanceRecord.subject_name == current_slot
        ).first()
        
        if not record:
            # Tạo bản ghi điểm danh mới
            record = AttendanceRecord(
                student_id=student.id,
                date=today,
                time_in=now_time,
                subject_name=current_slot, # Lưu slot vào cột subject_name!
                status=attendance_status
            )
            db.add(record)
            
            # Cập nhật JSON attendance_data của học sinh
            att_data = student.attendance_data or {}
            
            year_key = "2026-2027"
            semester_key = "Học kỳ 1"
            if classroom:
                year_key = f"{classroom.current_year_start}-{classroom.current_year_end}"
                semester_key = classroom.current_semester
                
            if year_key not in att_data:
                att_data[year_key] = {}
            if semester_key not in att_data[year_key]:
                att_data[year_key][semester_key] = {
                    "lateCount": 0,
                    "absentCount": 0,
                    "excusedCount": 0,
                    "history": []
                }
                
            term_data = att_data[year_key][semester_key]
            
            # Tăng số lần đi trễ nếu trạng thái là Đi trễ
            if attendance_status == "Đi trễ":
                term_data["lateCount"] = term_data.get("lateCount", 0) + 1
                
            # Ghi nhận vào lịch sử chi tiết
            date_str = today.strftime("%d/%m/%y")
            term_data["history"].append(f"{date_str}: {attendance_status} {current_slot} (Vào lúc {time_str})")
            
            student.attendance_data = att_data
            db.commit()
        else:
            status_response = "already_marked"
            if record.time_in:
                time_str = record.time_in.strftime("%H:%M")
            attendance_status = record.status
            
        class_name = student.classroom.class_name if student.classroom else "Không rõ"
        
        return {
            "status": status_response,
            "student_code": student.student_code,
            "student_name": student.full_name,
            "class_name": class_name,
            "attendance_status": attendance_status,
            "time_in": time_str,
            "current_slot": current_slot,
            "is_check_in": is_check_in,
            "confidence": confidence_pct
        }
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": f"Lỗi xử lý điểm danh AI: {e}"}

