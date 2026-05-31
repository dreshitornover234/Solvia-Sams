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
from typing import Optional
from datetime import time
from typing import List, Optional
from pydantic import BaseModel
from database import engine, Base
from fastapi.staticfiles import StaticFiles
import os
from datetime import datetime, date, time, timedelta

# Khai báo biến đếm thời gian cho Bộ quét tự động (Chèn ngoài hàm)

_last_sweep_time = datetime.min
# Khởi tạo ứng dụng
Base.metadata.create_all(bind=engine)
app = FastAPI(title="SAMS Backend API")
os.makedirs("uploads/avatars", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
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
class PeriodCreate(BaseModel):
    name: str
    start_time: str
    end_time: str

class ProjectCreate(BaseModel):
    project_name: str
    school_name: str
    academic_year: str
    project_type: str
    session_type: str
    attendance_mode: str
    global_rule: str
    morning_time: str
    afternoon_time: str
    bell_schedule: List[PeriodCreate] = [] # ---> THÊM MẢNG NÀY, BỎ MẢNG CLASSES
    user_id: int

class LiveLogItem(BaseModel):
    id: str
    time: Optional[str] = "Chưa rõ"
    period: Optional[str] = "Tiết hiện tại"
    status: Optional[str] = "Chưa điểm danh"
    detail: Optional[str] = "Không có ghi chú"
    type: Optional[str] = "info"
    subjectTeacher: Optional[str] = "Chưa gán"
    updatedBy: Optional[str] = "Hệ thống"
    teacher: Optional[str] = None # Giữ lại key cũ để không bị lỗi với dữ liệu cũ
    img: Optional[str] = None


class LiveUpdatePayload(BaseModel):
    status: str
    reason: Optional[str] = ""
    logs: list = []

@app.post("/api/create-project")
def create_project(project_data: ProjectCreate, db: Session = Depends(get_db)):
    try:
        # BƯỚC 1: Lưu thông tin Dự Án kèm Khung giờ
        new_project = Project(
            project_name=project_data.project_name,
            school_name=project_data.school_name,
            academic_year=project_data.academic_year,
            project_type=project_data.project_type,
            session_type=project_data.session_type,
            attendance_mode=project_data.attendance_mode,
            global_rule=project_data.global_rule,
            bell_schedule=[p.dict() for p in project_data.bell_schedule] # ---> LƯU VÀO DB
        )
        db.add(new_project)
        db.commit()
        db.refresh(new_project)

        # BƯỚC 2: GHI DANH SUPER ADMIN
        from database import ProjectMember
        owner = ProjectMember(
            project_id=new_project.id,
            user_id=project_data.user_id,
            role="Super Admin",
            status="Hoạt động"
        )
        db.add(owner)
        db.commit()

        return {
            "status": "success",
            "message": "Khởi tạo Cấu trúc Dự án & Khung giờ thành công!",
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


# =====================================================================
# API ĐĂNG NHẬP (QUÉT 2 TẦNG: GIÁO VIÊN VÀ HỌC SINH)
# =====================================================================
import shutil
import os
from fastapi import UploadFile, File, Query


@app.post("/api/login")
def login_user(login_data: dict, db: Session = Depends(get_db)):
    from database import Staff, Student, ProjectMember
    username = login_data.get("username", "").strip()
    password = login_data.get("password", "")
    role_request = login_data.get("role", "Thành viên")

    # 1. NẾU YÊU CẦU QUYỀN ADMIN -> CHỈ QUÉT BẢNG GIÁO VIÊN
    if role_request == "Admin":
        staff_user = db.query(Staff).filter(
            (Staff.email == username) | (Staff.username == username)
        ).first()

        if staff_user:
            if staff_user.password != password:
                return {"status": "error", "message": "Sai mật khẩu (Giáo viên/Admin)!"}

            member = db.query(ProjectMember).filter(ProjectMember.user_id == staff_user.id).first()
            actual_role = member.role if member else "Super Admin"

            return {
                "status": "success", "message": "Đăng nhập Giáo viên thành công!",
                "data": {"user_id": staff_user.id, "role": actual_role,
                         "setting_theme_color": getattr(staff_user, 'setting_theme_color', "0xFF448AFF"),
                         "setting_font_scale": getattr(staff_user, 'setting_font_scale', 1.0),
                         "setting_language": getattr(staff_user, 'setting_language', "Tiếng Việt"),
                         "setting_timezone": getattr(staff_user, 'setting_timezone', "UTC +07:00 (Hồ Chí Minh)")}
            }
        return {"status": "error", "message": "Tài khoản Giáo viên/Admin không tồn tại!"}

    # 2. NẾU YÊU CẦU QUYỀN THÀNH VIÊN -> CHỈ QUÉT BẢNG HỌC SINH
    elif role_request == "Thành viên":
        student_user = db.query(Student).filter(
            (Student.email == username) | (Student.username == username)
        ).first()

        if student_user:
            if student_user.password != password:
                return {"status": "error", "message": "Sai mật khẩu Học sinh!"}

            return {
                "status": "success", "message": "Đăng nhập Học sinh thành công!",
                "data": {"user_id": student_user.id, "role": "Học sinh", "setting_theme_color": "0xFF448AFF",
                         "setting_font_scale": 1.0, "setting_language": "Tiếng Việt",
                         "setting_timezone": "UTC +07:00 (Hồ Chí Minh)"}
            }
        return {"status": "error", "message": "Tài khoản Học sinh không tồn tại!"}

    return {"status": "error", "message": "Quyền truy cập không hợp lệ!"}


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
def get_user_profile(user_id: int, role: str = Query(None), db: Session = Depends(get_db)):
    from database import Staff, Student
    is_student = (role in ["Học sinh", "Thành viên"])

    if is_student:
        student = db.query(Student).filter(Student.id == user_id).first()
        if student:
            return {"status": "success", "data": {
                "avatar_url": getattr(student, "avatar_url", ""),
                "face_data": getattr(student, "face_data", ""), # <--- TÁCH BIỆT DỮ LIỆU FACE ID
                "full_name": getattr(student, "full_name", ""),
                "email": getattr(student, "email", getattr(student, "username", "")),
                "phone": getattr(student, "phone", ""),
                "dob": getattr(student, "dob", ""),
                "hometown": getattr(student, "hometown", ""),
                "current_address": getattr(student, "current_address", ""),
                "religion": getattr(student, "religion", ""),
                "facebook": getattr(student, "facebook", ""),
                "role": "Học sinh", "position": "Học sinh",
                "degree": "", "graduated_from": "", "dynamic_1": "", "dynamic_2": "", "dynamic_3": ""
            }}
    else:
        staff = db.query(Staff).filter(Staff.id == user_id).first()
        if staff:
            return {"status": "success", "data": {
                "avatar_url": getattr(staff, "avatar_url", ""),
                "face_data": "", # Giáo viên không dùng Face ID
                "full_name": getattr(staff, "full_name", ""),
                "email": getattr(staff, "email", ""),
                "phone": getattr(staff, "phone", ""),
                "dob": getattr(staff, "dob", ""),
                "hometown": getattr(staff, "hometown", ""),
                "current_address": getattr(staff, "current_address", ""),
                "religion": getattr(staff, "religion", ""),
                "facebook": getattr(staff, "facebook", ""),
                "role": getattr(staff, "role", ""),
                "position": getattr(staff, "position", ""),
                "degree": getattr(staff, "degree", ""),
                "graduated_from": getattr(staff, "graduated_from", ""),
                "dynamic_1": getattr(staff, "dynamic_1", ""),
                "dynamic_2": getattr(staff, "dynamic_2", ""),
                "dynamic_3": getattr(staff, "dynamic_3", "")
            }}
    return {"status": "error", "message": "Không tìm thấy người dùng!"}




@app.post("/api/students/{student_identifier}/live_update")
def update_live_status(student_identifier: str, payload: LiveUpdatePayload, db: Session = Depends(get_db)):
    from database import Student, AttendanceRecord, ClassRoom
    from sqlalchemy.orm.attributes import flag_modified
    from datetime import datetime
    import copy

    # ĐÃ FIX: CHẤP NHẬN CẢ MÃ HỌC SINH (07HS001) LẪN ID BẰNG SỐ (1, 2, 3...)
    student = db.query(Student).filter(Student.student_code == student_identifier).first()
    if not student and student_identifier.isdigit():
        student = db.query(Student).filter(Student.id == int(student_identifier)).first()

    if not student:
        return {"status": "error", "message": "Không tìm thấy học sinh trong hệ thống!"}

    try:
        now = datetime.now()
        today = now.date()
        today_str = today.strftime('%d/%m/%y')

        att_data = copy.deepcopy(student.attendance_data) if student.attendance_data else {}
        classroom = getattr(student, 'classroom', None)
        year_key = f"{getattr(classroom, 'current_year_start', '2026')}-{getattr(classroom, 'current_year_end', '2027')}" if classroom else "2026-2027"
        semester_key = getattr(classroom, 'current_semester', 'Học kỳ 1') if classroom else "Học kỳ 1"

        if year_key not in att_data: att_data[year_key] = {}
        if semester_key not in att_data[year_key]:
            att_data[year_key][semester_key] = {"lateCount": 0, "absentCount": 0, "excusedCount": 0, "history": []}

        term_data = att_data[year_key][semester_key]

        # Lấy tên tiết học từ Giao diện gửi lên
        latest_log = payload.logs[0] if payload.logs else {}
        period_name = latest_log.get("period", "Tiết hiện tại") if isinstance(latest_log, dict) else "Tiết hiện tại"

        # 1. QUÉT TÌM VÀ TRỪ ĐI SỐ LIỆU CŨ (Tránh đếm trùng)
        old_status = None
        if "history" in term_data:
            for h in term_data["history"]:
                if h.startswith(today_str) and period_name in h:
                    if "Đi trễ" in h:
                        old_status = "Đi trễ"
                    elif "Vắng mặt" in h or "Nghỉ học" in h:
                        old_status = "Vắng mặt"
                    elif "Có phép" in h:
                        old_status = "Có phép"
                    break

        if old_status == "Đi trễ" and term_data.get("lateCount", 0) > 0: term_data["lateCount"] -= 1
        if old_status == "Vắng mặt" and term_data.get("absentCount", 0) > 0: term_data["absentCount"] -= 1
        if old_status == "Có phép" and term_data.get("excusedCount", 0) > 0: term_data["excusedCount"] -= 1

        # 2. CỘNG DỒN SỐ LIỆU MỚI DO GIÁO VIÊN SỬA
        if payload.status == "Đi trễ": term_data["lateCount"] = term_data.get("lateCount", 0) + 1
        if payload.status in ["Vắng mặt", "Nghỉ học"]: term_data["absentCount"] = term_data.get("absentCount", 0) + 1
        if payload.status == "Có phép": term_data["excusedCount"] = term_data.get("excusedCount", 0) + 1

        # 3. GHI ĐÈ VÀO LỊCH SỬ DÒNG THỜI GIAN
        reason_str = payload.reason if payload.reason else "Giáo viên cập nhật nhanh"
        if "history" not in term_data: term_data["history"] = []
        term_data["history"].insert(0,
                                    f"{today_str}: Sửa thành {payload.status} {period_name} (Lý do: {reason_str})|img:none")

        # 4. ĐỒNG BỘ VÀO BẢNG ĐIỂM DANH GỐC (AttendanceRecord)
        record = db.query(AttendanceRecord).filter(
            AttendanceRecord.student_id == student.id, AttendanceRecord.date == today,
            AttendanceRecord.subject_name == period_name
        ).first()

        if record:
            record.status = payload.status
            record.time_in = now.time()
        else:
            record = AttendanceRecord(student_id=student.id, date=today, time_in=now.time(), subject_name=period_name,
                                      status=payload.status)
            db.add(record)

        student.attendance_data = att_data
        flag_modified(student, "attendance_data")
        db.commit()

        return {"status": "success", "message": "Đã cập nhật trạng thái thành công"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": str(e)}
# 2. Cổng lưu thông tin (PUT)
@app.put("/api/users/{user_id}")
def update_user_profile(user_id: int, profile_data: dict, role: str = Query(None), db: Session = Depends(get_db)):
    from database import Staff, Student
    is_student = (role in ["Học sinh", "Thành viên"])

    if not is_student:
        staff = db.query(Staff).filter(Staff.id == user_id).first()
        if staff:
            for key, value in profile_data.items():
                if hasattr(staff, key): setattr(staff, key, value)
            db.commit()
            return {"status": "success", "message": "Cập nhật thành công"}
    else:
        student = db.query(Student).filter(Student.id == user_id).first()
        if student:
            for key, value in profile_data.items():
                if hasattr(student, key) and key not in ["position", "degree", "graduated_from", "dynamic_1",
                                                         "dynamic_2", "dynamic_3"]:
                    setattr(student, key, value)
                if key == "full_name" and hasattr(student, "name"):
                    setattr(student, "name", value)
            db.commit()
            return {"status": "success", "message": "Cập nhật thành công"}
    return {"status": "error", "message": "Không tìm thấy người dùng!"}

# =====================================================================
# API UPLOAD ẢNH ĐẠI DIỆN
# =====================================================================
import shutil
import os
from fastapi import UploadFile, File

import shutil
import os
from fastapi import UploadFile, File, Query


@app.post("/api/users/{user_id}/avatar")
def upload_avatar(user_id: int, role: str = Query(None), file: UploadFile = File(...), db: Session = Depends(get_db)):
    from database import Staff, Student
    import os, shutil
    is_student = (role in ["Học sinh", "Thành viên"])

    user = db.query(Student).filter(Student.id == user_id).first() if is_student else db.query(Staff).filter(
        Staff.id == user_id).first()
    if not user: return {"status": "error", "message": "Không tìm thấy tài khoản"}

    try:
        os.makedirs("static/avatars", exist_ok=True)
        safe_filename = file.filename.replace(" ", "_")
        prefix = "student" if is_student else "staff"
        file_location = f"static/avatars/{prefix}_{user_id}_{safe_filename}"

        with open(file_location, "wb+") as file_object:
            shutil.copyfileobj(file.file, file_object)

        user.avatar_url = f"/{file_location}"  # <--- CHỈ LƯU AVATAR
        db.commit()
        return {"status": "success", "message": "Cập nhật ảnh thành công!", "avatar_url": user.avatar_url}
    except Exception as e:
        return {"status": "error", "message": f"Lỗi lưu ảnh: {str(e)}"}


# 3. TÌM VÀ SỬA API ĐĂNG KÝ FACE ID (Chỉ lưu vào face_data)
class FaceRegisterRequest(BaseModel):
    image_base64: str

@app.put("/api/users/{user_id}/password")
def change_password(user_id: int, payload: dict, role: str = Query(None), db: Session = Depends(get_db)):
    from database import Staff, Student
    is_student = (role in ["Học sinh", "Thành viên"])
    user = db.query(Student).filter(Student.id == user_id).first() if is_student else db.query(Staff).filter(
        Staff.id == user_id).first()

    if not user: return {"status": "error", "message": "Không tìm thấy người dùng!"}
    if user.password != payload.get("old_password"): return {"status": "error",
                                                             "message": "Mật khẩu cũ không chính xác!"}

    user.password = payload.get("new_password")
    db.commit()
    return {"status": "success", "message": "Đổi mật khẩu thành công!"}


@app.put("/api/users/{user_id}/settings")
def update_settings(user_id: int, payload: dict, role: str = Query(None), db: Session = Depends(get_db)):
    from database import Staff, Student
    is_student = (role in ["Học sinh", "Thành viên"])
    user = db.query(Student).filter(Student.id == user_id).first() if is_student else db.query(Staff).filter(
        Staff.id == user_id).first()

    if not user: return {"status": "error", "message": "Không tìm thấy người dùng!"}

    try:
        if hasattr(user, 'setting_language'): user.setting_language = payload.get("language")
        if hasattr(user, 'setting_timezone'): user.setting_timezone = payload.get("timezone")
        if hasattr(user, 'setting_theme_color'): user.setting_theme_color = payload.get("theme_color")
        if hasattr(user, 'setting_font_scale'): user.setting_font_scale = payload.get("font_scale")
        db.commit()
    except:
        pass  # Bỏ qua nếu Học sinh không có trường Cài đặt
    return {"status": "success"}


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
    from database import Project, ClassRoom, Student, ProjectMember
    project = db.query(Project).filter(Project.id == project_id).first()

    if not project:
        return {"status": "error", "message": "Không tìm thấy dự án"}

    total_students = db.query(Student).join(ClassRoom).filter(ClassRoom.project_id == project_id).count()
    total_staff = db.query(ProjectMember).filter(ProjectMember.project_id == project_id,
                                                 ProjectMember.status == "Hoạt động").count()

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

            # ---> DÒNG CỰC KỲ QUAN TRỌNG ĐÃ FIX LỖI MẤT TIẾT HỌC <---
            "bell_schedule": project.bell_schedule or [],

            "total_students": total_students,
            "total_staff": total_staff,
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
    # Lấy danh sách Học sinh
    students = db.query(Student).filter(Student.class_id == class_id).all()
    student_list = []

    for st in students:
        att_data = st.attendance_data or {}
        student_list.append({
            "id": st.student_code or "Chưa cấp",
            "name": st.full_name or "Không tên",
            "gender": st.gender or "Nam",
            "dob": st.dob or "Chưa cập nhật",
            "parent": st.parent_name or "Chưa cập nhật",
            "phone": st.phone or "Chưa cập nhật",
            "email": st.email or st.username or "Chưa cập nhật",
            "avatar_url": getattr(st, "avatar_url", ""),
            "hometown": getattr(st, "hometown", ""),
            "current_address": getattr(st, "current_address", ""),
            "religion": getattr(st, "religion", ""),
            "facebook": getattr(st, "facebook", ""),
            "face_data": getattr(st, "face_data", ""),

            "live_status": att_data.get("live_status", "Chưa điểm danh"),
            "live_logs": att_data.get("live_logs", []),
            "live_reason": att_data.get("live_reason", ""),
            "attendance": att_data
        })

    # Đóng gói thông tin GVCN
    teacher_info = {}
    if teacher:
        teacher_info = {
            "id": teacher.id,              # <--- ĐÃ FIX: TRẢ VỀ ID
            "user_id": teacher.id,         # <--- ĐÃ FIX: TRẢ VỀ USER_ID CHO MENU FLUTTER NHẬN DIỆN
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
            "timetable": classroom.timetable or [],
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
    classes = db.query(ClassRoom).filter(ClassRoom.project_id == project_id).all()

    data = []
    for c in classes:
        data.append({
            "id": c.id,
            "class_name": c.class_name,
            "teacher_id": c.teacher_id  # <--- ĐÃ FIX: TRẢ VỀ CẢ ID GIÁO VIÊN
        })

    return {"status": "success", "data": data}





# =====================================================================
# API CẬP NHẬT CẤU HÌNH LỚP VÀ THỜI KHÓA BIỂU
# =====================================================================
class ClassUpdate(BaseModel):
    class_name: str
    teacher_id: Optional[int] = None
    course_start_year: int
    course_end_year: int
    current_year_start: int
    current_year_end: int
    current_semester: str
    timetable: list


# CẬP NHẬT 1: CHỐNG GHI ĐÈ MẤT GIÁO VIÊN CHỦ NHIỆM
@app.put("/api/classes/{class_id}")
def update_class_detail(class_id: int, class_data: ClassUpdate, db: Session = Depends(get_db)):
    from database import ClassRoom, ProjectMember
    classroom = db.query(ClassRoom).filter(ClassRoom.id == class_id).first()
    if not classroom:
        return {"status": "error", "message": "Không tìm thấy lớp học"}

    try:
        # CHỈ CẬP NHẬT GVCN KHI CÓ DỮ LIỆU GỬI LÊN (Chống lỗi mất GVCN khi lưu TKB)
        if class_data.teacher_id is not None:
            if class_data.teacher_id != classroom.teacher_id:
                if classroom.teacher_id:
                    old_teacher = db.query(ProjectMember).filter(ProjectMember.user_id == classroom.teacher_id,
                                                                 ProjectMember.project_id == classroom.project_id).first()
                    if old_teacher: old_teacher.unit = None
                new_teacher = db.query(ProjectMember).filter(ProjectMember.user_id == class_data.teacher_id,
                                                             ProjectMember.project_id == classroom.project_id).first()
                if new_teacher: new_teacher.unit = class_data.class_name
            classroom.teacher_id = class_data.teacher_id

        classroom.class_name = class_data.class_name
        classroom.course_start_year = class_data.course_start_year
        classroom.course_end_year = class_data.course_end_year
        classroom.current_year_start = class_data.current_year_start
        classroom.current_year_end = class_data.current_year_end
        classroom.current_semester = class_data.current_semester
        classroom.timetable = class_data.timetable

        db.commit()
        return {"status": "success"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": str(e)}


# CẬP NHẬT 2: CHỐNG GHI ĐÈ LỖI BẢNG THÀNH VIÊN
class MemberUpdateRequest(BaseModel):
    status: str
    role: str
    unit: Optional[str] = None
    teaching_subject: Optional[str] = None
@app.put("/api/members/{member_id}")
def update_project_member(member_id: int, request: MemberUpdateRequest, db: Session = Depends(get_db)):
    from database import ProjectMember, ClassRoom
    member = db.query(ProjectMember).filter(ProjectMember.id == member_id).first()
    if not member: return {"status": "error", "message": "Không tìm thấy thành viên!"}

    member.status = request.status
    member.role = request.role

    # CHỈ LƯU NẾU CÓ TRUYỀN LÊN TỪ FLUTTER
    if request.unit is not None:
        member.unit = request.unit
    if request.teaching_subject is not None:
        member.teaching_subject = request.teaching_subject

    if request.role == 'Unit Manager' and request.unit:
        target_class = db.query(ClassRoom).filter(
            ClassRoom.project_id == member.project_id,
            ClassRoom.class_name == request.unit
        ).first()
        if target_class:
            target_class.teacher_id = member.user_id

    db.commit()
    return {"status": "success"}


# =====================================================================
# API THAM GIA DỰ ÁN BẰNG MÁ
# =====================================================================
class JoinProjectRequest(BaseModel):
    project_code: str
    user_id: int


# =====================================================================
# API THAM GIA DỰ ÁN BẰNG MÃ
# =====================================================================
@app.post("/api/projects/join")
def join_project(payload: dict, db: Session = Depends(get_db)):
    code = payload.get("project_code")
    user_id = payload.get("user_id")

    # ĐÃ FIX: Sửa thành Project.project_code cho khớp với Database
    project = db.query(Project).filter(Project.project_code == code).first()
    if not project:
        return {"status": "error", "message": "Mã dự án không tồn tại. Vui lòng kiểm tra lại!"}

    from database import ProjectMember
    # Kiểm tra xem user đã ở trong dự án chưa
    existing_member = db.query(ProjectMember).filter(
        ProjectMember.project_id == project.id,
        ProjectMember.user_id == user_id
    ).first()

    if existing_member:
        return {"status": "error", "message": "Bạn đã gửi yêu cầu hoặc đang ở trong dự án này rồi."}

    # Thêm user vào dự án với trạng thái "Chờ duyệt"
    new_member = ProjectMember(
        project_id=project.id,
        user_id=user_id,
        role="Ứng viên",
        status="Chờ duyệt"
    )
    db.add(new_member)
    db.commit()

    return {"status": "success", "message": "Đã gửi yêu cầu tham gia. Vui lòng chờ Admin duyệt!"}

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
    from database import ProjectMember, Staff
    try:
        members = db.query(ProjectMember, Staff).join(Staff, ProjectMember.user_id == Staff.id).filter(
            ProjectMember.project_id == project_id).all()

        admins = []
        managers = []
        pending = []

        for member_link, staff_user in members:
            # ĐÃ FIX: Bổ sung "teaching_subject" và "unit" vào gói dữ liệu trả về
            member_data = {
                "id": member_link.id,
                "user_id": staff_user.id,
                "name": staff_user.full_name,
                "email": staff_user.email,
                "avatar_url": staff_user.avatar_url,
                "role": member_link.role,
                "status": member_link.status,
                "unit": member_link.unit,                               # <--- Bổ sung dòng này
                "teaching_subject": member_link.teaching_subject        # <--- Bổ sung dòng này
            }

            # PHÂN LOẠI DỮ LIỆU
            if member_link.status == "Chờ duyệt":
                pending.append(member_data)
            elif member_link.status == "Hoạt động":
                if "Admin" in (member_link.role or ""):
                    admins.append(member_data)
                else:
                    managers.append(member_data)

        return {
            "status": "success",
            "data": {
                "admins": admins,
                "managers": managers,
                "pending": pending
            }
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

class MemberUpdateRequest(BaseModel):
    status: str
    role: str # 'Super Admin', 'Unit Manager', 'Subject Teacher'
    unit: Optional[str] = None
    teaching_subject: Optional[str] = None # Thêm trường này



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
# API ĐĂNG KÝ GÓI SẢN PHẨM / DỊCH VỤ
# =====================================================================
class ProjectSubscribe(BaseModel):
    package_name: str
    server_specs: str
    storage_capacity: str
    max_students: int
    max_cameras: int
    included_cameras: int
    extra_cameras: int
    monthly_fee: int
    total_hardware_price: int
    upfront_payment: int
    remaining_payment: int
    payment_method: str


@app.post("/api/projects/{project_id}/subscribe")
def subscribe_project(project_id: int, sub_data: ProjectSubscribe, db: Session = Depends(get_db)):
    from database import Project
    project = db.query(Project).filter(Project.id == project_id).first()

    if not project:
        return {"status": "error", "message": "Không tìm thấy dự án. Vui lòng vào trang chủ chọn Dự án trước khi mua!"}

    try:
        # Cập nhật thông tin gói cước vào Dự án
        project.package_name = sub_data.package_name
        project.server_specs = sub_data.server_specs
        project.storage_capacity = sub_data.storage_capacity
        project.max_students = sub_data.max_students
        project.max_cameras = sub_data.max_cameras
        project.included_cameras = sub_data.included_cameras
        project.extra_cameras = sub_data.extra_cameras
        project.monthly_fee = sub_data.monthly_fee
        project.total_hardware_price = sub_data.total_hardware_price
        project.upfront_payment = sub_data.upfront_payment
        project.remaining_payment = sub_data.remaining_payment
        project.payment_method = sub_data.payment_method
        project.payment_status = "Chờ thanh toán"

        db.commit()
        return {"status": "success", "message": "Đã lưu hóa đơn. Yêu cầu đăng ký đã được gửi đến bộ phận CSKH!"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": f"Lỗi hệ thống: {str(e)}"}

# =====================================================================
# API TẠO LỚP HỌC MỚI VÀO DỰ ÁN (KHÔNG CÓ TKB)
# =====================================================================
class SingleStudentCreate(BaseModel):
    stt: str
    name: str
    gender: str
    dob: str
    hometown: str
    phone: str
    user: str
    pass_: str  # Đặt là pass_ vì 'pass' là từ khóa của Python

class SingleClassCreate(BaseModel):
    class_name: str
    students: List[SingleStudentCreate] = []

@app.post("/api/projects/{project_id}/classes")
def create_class_for_project(project_id: int, class_data: SingleClassCreate, db: Session = Depends(get_db)):
    from database import ClassRoom, Student
    try:
        # 1. Tạo lớp học mới (TKB để rỗng)
        new_class = ClassRoom(
            project_id=project_id,
            class_name=class_data.class_name,
            timetable=[] # Bỏ trống vì TKB sẽ được xếp ở màn hình TKB Chung sau
        )
        db.add(new_class)
        db.commit()
        db.refresh(new_class)

        # 2. Lưu danh sách học sinh từ file Excel vào lớp
        for std_data in class_data.students:
            new_student = Student(
                class_id=new_class.id,
                student_code=std_data.stt,
                full_name=std_data.name,
                gender=std_data.gender,
                dob=std_data.dob,
                hometown=std_data.hometown,
                phone=std_data.phone,
                username=std_data.user,
                email=std_data.user,
                password=std_data.pass_
            )
            db.add(new_student)
        db.commit()

        return {"status": "success", "message": "Tạo lớp thành công!"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": str(e)}


# =====================================================================
# API DÀNH CHO TRANG CHỦ HỌC SINH (STUDENT DASHBOARD)
# =====================================================================
@app.get("/api/students/{user_id}/dashboard")
def get_student_dashboard(user_id: int, db: Session = Depends(get_db)):
    from database import Student, ClassRoom, Project
    # Tìm học sinh
    student = db.query(Student).filter(Student.id == user_id).first()
    if not student:
        return {"status": "error", "message": "Không tìm thấy tài khoản học sinh."}

    # Tìm Lớp của học sinh đó
    classroom = db.query(ClassRoom).filter(ClassRoom.id == student.class_id).first()
    if not classroom:
        return {"status": "error", "message": "Học sinh chưa được xếp vào lớp nào."}

    # Tìm Dự án/Cơ sở chứa Lớp đó
    project = db.query(Project).filter(Project.id == classroom.project_id).first()

    return {
        "status": "success",
        "data": {
            "project_id": project.id,
            "project_name": project.project_name,
            "class_id": classroom.id,
            "class_name": classroom.class_name,
            "student_name": student.full_name
        }
    }


# =====================================================================
# =====================================================================
# PHẦN LÕI TÍCH HỢP HỆ THỐNG AI (OPENCV & FACE RECOGNITION)
# =====================================================================
# =====================================================================
import cv2
import numpy as np
import base64
from datetime import datetime, date, time, timedelta

# CÁC BIẾN TOÀN CỤC QUẢN LÝ CACHE MÔ HÌNH AI
_face_recognizer = None
_label_to_code = {}
_ai_needs_retrain = True


# =====================================================================
# 1. API ĐĂNG KÝ KHUÔN MẶT HỌC SINH (FACE ENROLLMENT)
# =====================================================================
class FaceRegisterRequest(BaseModel):
    image_base64: str


class FaceRegisterRequest(BaseModel):
    image_base64: str


@app.post("/api/users/{user_id}/register-face")
def register_student_face(user_id: int, request: FaceRegisterRequest, db: Session = Depends(get_db)):
    from database import Student
    import base64, os

    student = db.query(Student).filter(Student.id == user_id).first()
    if not student: return {"status": "error", "message": "Không tìm thấy học sinh!"}

    try:
        base64_data = request.image_base64
        if "," in base64_data: base64_data = base64_data.split(",")[1]

        image_bytes = base64.b64decode(base64_data)
        os.makedirs("static/avatars", exist_ok=True)
        file_location = f"static/avatars/face_data_hs_{user_id}.jpg"

        with open(file_location, "wb") as f:
            f.write(image_bytes)

        student.face_data = f"/{file_location}"  # <--- CHỈ LƯU VÀO CỘT FACE_DATA

        global _ai_needs_retrain
        _ai_needs_retrain = True
        db.commit()

        return {
            "status": "success",
            "message": "Đã lưu dữ liệu khuôn mặt thành công!",
            "face_data": student.face_data  # <--- TRẢ VỀ face_data
        }
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": f"Lỗi lưu trữ khuôn mặt: {str(e)}"}


# =====================================================================
# 2. HÀM HUẤN LUYỆN LẠI BỘ NÃO AI (TRAIN MODEL)
# =====================================================================

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
        # ĐÃ FIX: Ưu tiên lấy ảnh từ cột face_data (Nếu chưa quét Face ID thì mới lấy tạm avatar)
        face_img = getattr(st, 'face_data', None) or getattr(st, 'avatar_url', None)

        if face_img:
            img_path = face_img.lstrip('/')
            if os.path.exists(img_path):
                try:
                    # Đọc ảnh ở chế độ màu xám (Grayscale)
                    img = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)
                    if img is None:
                        continue

                    # Phát hiện khuôn mặt
                    detected_faces = face_cascade.detectMultiScale(img, scaleFactor=1.1, minNeighbors=5,
                                                                   minSize=(50, 50))
                    for (x, y, w, h) in detected_faces:
                        face_roi = img[y:y + h, x:x + w]
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


# =====================================================================
# API CAMERA AI: ĐIỂM DANH, QUÉT VẮNG MẶT & LƯU ẢNH BẰNG CHỨNG
# =====================================================================
from datetime import datetime, date, time, timedelta
import copy
from sqlalchemy.orm.attributes import flag_modified
import os

_last_sweep_time = datetime.min


class FaceRecognizeRequest(BaseModel):
    image_base64: str


@app.post("/api/attendance/recognize-face")
def recognize_face(request: FaceRecognizeRequest, db: Session = Depends(get_db)):
    global _face_recognizer, _label_to_code, _ai_needs_retrain, _last_sweep_time
    from database import Student, AttendanceRecord, Project, ClassRoom, LeaveRequest
    import base64, numpy as np
    import cv2

    now = datetime.now()
    today = now.date()
    now_time = now.time()
    time_str = now.strftime("%H:%M")

    days_vn = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ Nhật"]
    today_vn = days_vn[now.weekday()]
    valid_day_keys = [today_vn, today.strftime('%Y-%m-%d'), today.strftime('%d/%m/%Y')]

    # =====================================================================
    # 1. BỘ QUÉT TỰ ĐỘNG CHỐT "VẮNG MẶT"
    # =====================================================================
    if (now - _last_sweep_time).total_seconds() >= 10:
        _last_sweep_time = now
        try:
            active_classes = db.query(ClassRoom).all()
            for c in active_classes:
                if not getattr(c, 'timetable', None): continue
                for day in c.timetable:
                    if day.get("dayName") in valid_day_keys:
                        for sub in day.get("subjects", []):
                            if sub.get("status") == "Trống": continue
                            try:
                                times = sub.get("timeFrame", "").split('-')
                                sh, sm = map(int, times[0].strip().split(':'))
                                eh, em = map(int, times[1].strip().split(':'))
                                start_t = time(sh, sm)
                                end_t = time(eh, em)

                                if start_t <= now_time <= end_t:
                                    class_students = db.query(Student).filter(Student.class_id == c.id).all()
                                    for st in class_students:
                                        has_record = db.query(AttendanceRecord).filter(
                                            AttendanceRecord.student_id == st.id,
                                            AttendanceRecord.date == today,
                                            AttendanceRecord.subject_name == sub.get("name")
                                        ).first()

                                        if not has_record:
                                            has_leave = db.query(LeaveRequest).filter(
                                                LeaveRequest.student_id == st.id, LeaveRequest.is_approved == True,
                                                LeaveRequest.start_date <= today,
                                                (LeaveRequest.end_date >= today) | (LeaveRequest.end_date == None)
                                            ).all()

                                            is_excused = False
                                            for l in has_leave:
                                                if l.leave_mode in ['Nguyên ngày', 'Theo ngày']:
                                                    is_excused = True; break
                                                elif l.leave_mode == 'Theo tiết' and l.subject_name == sub.get("name"):
                                                    is_excused = True; break

                                            new_status = "Có phép" if is_excused else "Vắng mặt"

                                            new_record = AttendanceRecord(student_id=st.id, date=today,
                                                                          time_in=now_time,
                                                                          subject_name=sub.get("name"),
                                                                          status=new_status)
                                            db.add(new_record)

                                            att_data = copy.deepcopy(st.attendance_data) if st.attendance_data else {}
                                            year_key = f"{getattr(c, 'current_year_start', '2026')}-{getattr(c, 'current_year_end', '2027')}"
                                            semester_key = getattr(c, 'current_semester', 'Học kỳ 1')

                                            if year_key not in att_data: att_data[year_key] = {}
                                            if semester_key not in att_data[year_key]:
                                                att_data[year_key][semester_key] = {"lateCount": 0, "absentCount": 0,
                                                                                    "excusedCount": 0, "history": []}

                                            term_data = att_data[year_key][semester_key]
                                            if new_status == "Vắng mặt":
                                                term_data["absentCount"] = term_data.get("absentCount", 0) + 1
                                            elif new_status == "Có phép":
                                                term_data["excusedCount"] = term_data.get("excusedCount", 0) + 1

                                            term_data["history"].insert(0,
                                                                        f"{today.strftime('%d/%m/%y')}: {new_status} {sub.get('name')} (Hệ thống tự chốt)|img:none")

                                            st.attendance_data = att_data
                                            flag_modified(st, "attendance_data")
                                            db.commit()
                            except Exception:
                                pass
        except Exception as e:
            print(f"[AUTO SWEEP] Lỗi: {e}")

    # =====================================================================
    # 2. XỬ LÝ NHẬN DIỆN VÀ LƯU ẢNH
    # =====================================================================
    if _ai_needs_retrain or _face_recognizer is None:
        try:
            train_face_recognizer(db)
        except Exception:
            pass

    try:
        base64_data = request.image_base64
        if "," in base64_data: base64_data = base64_data.split(",")[1]
        image_bytes = base64.b64decode(base64_data)
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_GRAYSCALE)
    except Exception as e:
        return {"status": "error", "message": f"Lỗi giải mã ảnh: {e}"}

    if img is None: return {"status": "error", "message": "Ảnh gửi lên không hợp lệ."}

    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    detected_faces = face_cascade.detectMultiScale(img, scaleFactor=1.1, minNeighbors=5, minSize=(50, 50))

    if len(detected_faces) == 0: return {"status": "no_face"}
    if _face_recognizer is None: return {"status": "unknown"}

    results = []
    for (x, y, w, h) in detected_faces:
        face_roi = cv2.resize(img[y:y + h, x:x + w], (200, 200))
        try:
            label, distance = _face_recognizer.predict(face_roi)
            confidence_pct = max(0.0, min(100.0, (120.0 - distance) / 120.0 * 100.0))

            if distance > 85.0 or label not in _label_to_code: continue

            student_code = _label_to_code[label]
            student = db.query(Student).filter(Student.student_code == student_code).first()
            if not student: continue

            classroom = getattr(student, 'classroom', None)
            project = classroom.project if classroom else None
            class_name = classroom.class_name if classroom else "Không rõ"

            attendance_status = "Có mặt"
            current_slot = "Giờ hành chính"
            is_late = False

            # ==============================================================
            # ĐÃ FIX: MỞ RỘNG KHUNG GIỜ CHECK-IN TRƯỚC 30 PHÚT VÀ ƯU TIÊN TKB
            # ==============================================================
            has_timetable_today = False
            is_in_class = False

            if classroom and getattr(classroom, 'timetable', None):
                for day in classroom.timetable:
                    if day.get("dayName") in valid_day_keys:
                        has_timetable_today = True
                        for sub in day.get("subjects", []):
                            if sub.get("status") == "Trống": continue
                            try:
                                times = sub.get("timeFrame", "").split('-')
                                sh, sm = map(int, times[0].strip().split(':'))
                                eh, em = map(int, times[1].strip().split(':'))
                                start_t = time(sh, sm);
                                end_t = time(eh, em)

                                # CHO PHÉP ĐIỂM DANH TRƯỚC 30 PHÚT
                                start_dt = datetime.combine(today, start_t)
                                checkin_start = (start_dt - timedelta(minutes=30)).time()

                                if checkin_start <= now_time <= end_t:
                                    is_in_class = True
                                    current_slot = sub.get("name", "Tiết học")

                                    late_mins = sm + 15
                                    late_threshold = time(sh + (late_mins // 60), late_mins % 60)
                                    if now_time > late_threshold:
                                        attendance_status = "Đi trễ"
                                        is_late = True
                                    else:
                                        attendance_status = "Có mặt"
                                    break
                            except Exception:
                                pass
                        if is_in_class: break

            if has_timetable_today:
                if not is_in_class:
                    attendance_status = "Trống tiết"
                    current_slot = "Ngoài giờ học"
            else:
                # DỰ PHÒNG: NẾU KHÔNG CÓ THỜI KHÓA BIỂU
                morning_start = time(7, 30, 0);
                morning_end = time(12, 0, 0)
                afternoon_start = time(13, 30, 0);
                afternoon_end = time(17, 0, 0)

                if project:
                    if getattr(project, 'morning_time', None) and "-" in project.morning_time:
                        try:
                            parts = project.morning_time.split("-")
                            sh, sm = map(int, parts[0].strip().split(":"))
                            eh, em = map(int, parts[1].strip().split(":"))
                            morning_start = time(sh, sm, 0);
                            morning_end = time(eh, em, 0)
                        except:
                            pass
                    if getattr(project, 'afternoon_time', None) and "-" in project.afternoon_time:
                        try:
                            parts = project.afternoon_time.split("-")
                            sh, sm = map(int, parts[0].strip().split(":"))
                            eh, em = map(int, parts[1].strip().split(":"))
                            afternoon_start = time(sh, sm, 0);
                            afternoon_end = time(eh, em, 0)
                        except:
                            pass

                if now_time <= morning_end:
                    current_slot = "Buổi Sáng"
                    late_mins = morning_start.minute + 15
                    late_threshold = time(morning_start.hour + (late_mins // 60), late_mins % 60)
                    if now_time > late_threshold: attendance_status = "Đi trễ"; is_late = True
                elif now_time <= afternoon_end:
                    current_slot = "Buổi Chiều"
                    late_mins = afternoon_start.minute + 15
                    late_threshold = time(afternoon_start.hour + (late_mins // 60), late_mins % 60)
                    if now_time > late_threshold: attendance_status = "Đi trễ"; is_late = True
                else:
                    current_slot = "Ngoài giờ"
                    attendance_status = "Có mặt"

            status_response = "success"

            os.makedirs("static/attendance", exist_ok=True)
            img_filename = f"/static/attendance/{student.id}_{now.strftime('%Y%m%d%H%M%S')}.jpg"
            with open("." + img_filename, "wb") as f:
                f.write(image_bytes)

            if attendance_status != "Trống tiết":
                record = db.query(AttendanceRecord).filter(
                    AttendanceRecord.student_id == student.id, AttendanceRecord.date == today,
                    AttendanceRecord.subject_name == current_slot
                ).first()

                if not record:
                    record = AttendanceRecord(student_id=student.id, date=today, time_in=now_time,
                                              subject_name=current_slot, status=attendance_status)
                    db.add(record)

                    att_data = copy.deepcopy(student.attendance_data) if student.attendance_data else {}
                    year_key = f"{getattr(classroom, 'current_year_start', '2026')}-{getattr(classroom, 'current_year_end', '2027')}" if classroom else "2026-2027"
                    semester_key = getattr(classroom, 'current_semester', 'Học kỳ 1') if classroom else "Học kỳ 1"

                    if year_key not in att_data: att_data[year_key] = {}
                    if semester_key not in att_data[year_key]:
                        att_data[year_key][semester_key] = {"lateCount": 0, "absentCount": 0, "excusedCount": 0,
                                                            "history": []}

                    if attendance_status == "Đi trễ": att_data[year_key][semester_key]["lateCount"] += 1

                    att_data[year_key][semester_key]["history"].insert(0,
                                                                       f"{today.strftime('%d/%m/%y')}: {attendance_status} {current_slot} (Vào lúc {time_str})|img:{img_filename}")

                    student.attendance_data = att_data
                    flag_modified(student, "attendance_data")
                    db.commit()
                else:
                    if record.status == "Vắng mặt" or record.status == "Chưa điểm danh":
                        record.status = attendance_status
                        record.time_in = now_time

                        att_data = copy.deepcopy(student.attendance_data) if student.attendance_data else {}
                        year_key = f"{getattr(classroom, 'current_year_start', '2026')}-{getattr(classroom, 'current_year_end', '2027')}" if classroom else "2026-2027"
                        semester_key = getattr(classroom, 'current_semester', 'Học kỳ 1') if classroom else "Học kỳ 1"
                        term_data = att_data.get(year_key, {}).get(semester_key, {})

                        if term_data.get("absentCount", 0) > 0: term_data["absentCount"] -= 1
                        if is_late: term_data["lateCount"] = term_data.get("lateCount", 0) + 1

                        if "history" not in term_data: term_data["history"] = []
                        term_data["history"].insert(0,
                                                    f"{today.strftime('%d/%m/%y')}: Sửa thành {attendance_status} {current_slot} (Cập nhật lúc {time_str})|img:{img_filename}")

                        student.attendance_data = att_data
                        flag_modified(student, "attendance_data")
                        db.commit()
                    else:
                        status_response = "already_marked"
                        if record.time_in: time_str = record.time_in.strftime("%H:%M")
                        attendance_status = record.status

            results.append({
                "status": status_response, "student_code": student.student_code,
                "student_name": getattr(student, 'full_name', getattr(student, 'name', '')),
                "class_name": class_name, "attendance_status": attendance_status, "time_in": time_str,
                "current_slot": current_slot, "confidence": confidence_pct
            })
        except Exception as e:
            db.rollback()
            continue

    if len(results) == 0: return {"status": "unknown"}

    return {
        "status": results[0]["status"], "student_code": results[0]["student_code"],
        "student_name": results[0]["student_name"],
        "class_name": results[0]["class_name"], "attendance_status": results[0]["attendance_status"],
        "time_in": results[0]["time_in"],
        "current_slot": results[0]["current_slot"], "confidence": results[0]["confidence"], "results": results
    }
# =====================================================================
# API LẤY BÁO CÁO ĐIỂM DANH LIVE HÔM NAY (ĐÃ TÍCH HỢP LOGIC KIỂM TOÁN TỪNG TIẾT)
# =====================================================================
@app.get("/api/projects/{project_id}/attendance-today")
def get_project_attendance_today(project_id: int, db: Session = Depends(get_db)):
    from database import Project, ClassRoom, Student, AttendanceRecord, LeaveRequest, Staff
    try:
        project = db.query(Project).filter(Project.id == project_id).first()
        if not project: return {"status": "error", "message": "Không tìm thấy dự án"}

        attendance_mode = project.attendance_mode or "Quy định chung toàn trường"
        today = date.today()
        current_time_val = datetime.now().time()
        days_vn = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ Nhật"]
        today_vn = days_vn[datetime.now().weekday()]

        classes = db.query(ClassRoom).filter(ClassRoom.project_id == project_id).all()
        subject_mode_list = []

        for c in classes:
            teacher = db.query(Staff).filter(Staff.id == c.teacher_id).first() if c.teacher_id else None
            teacher_name = teacher.full_name if teacher else "Chưa phân công"
            students = db.query(Student).filter(Student.class_id == c.id).all()
            total_students = len(students)

            if total_students == 0: continue

            student_ids = [s.id for s in students]
            # 1. Kéo toàn bộ log AI quét camera hôm nay
            records = db.query(AttendanceRecord).filter(AttendanceRecord.student_id.in_(student_ids),
                                                        AttendanceRecord.date == today).all()
            # 2. Kéo toàn bộ Đơn xin nghỉ phép hôm nay
            leaves = db.query(LeaveRequest).filter(LeaveRequest.student_id.in_(student_ids),
                                                   LeaveRequest.start_date <= today,
                                                   (LeaveRequest.end_date >= today) | (LeaveRequest.end_date == None),
                                                   LeaveRequest.is_approved == True).all()

            student_records = {}
            for r in records: student_records.setdefault(r.student_id, []).append(r)
            student_leaves = {}
            for l in leaves: student_leaves.setdefault(l.student_id, []).append(l)

            # Lấy các môn học đang có trong Thời khóa biểu của Lớp vào Hôm nay
            today_subjects = []
            if c.timetable:
                for day_data in c.timetable:
                    if day_data.get("dayName") == today_vn:
                        today_subjects = [s for s in day_data.get("subjects", []) if s.get("status") != "Trống"]
                        break

            total_periods_today = len(today_subjects)
            present_count = 0
            subj_violations = []

            for s in students:
                s_records = student_records.get(s.id, [])
                s_leaves = student_leaves.get(s.id, [])

                # Cờ kiểm tra Nghỉ Nguyên Ngày
                is_full_day_leave = any(l.leave_mode == "Nguyên ngày" for l in s_leaves)
                leave_subjects = [l.subject_name for l in s_leaves if l.leave_mode == "Theo tiết"]

                # =======================================================
                # LUỒNG LOGIC 1: ĐIỂM DANH THEO TỪNG TIẾT HỌC
                # =======================================================
                if attendance_mode == "Theo từng Tiết học":
                    if total_periods_today > 0:
                        absent_periods = []
                        late_periods = []
                        excused_periods = []

                        for sub in today_subjects:
                            sub_name = sub.get("name", "").replace("[Bù] ", "").strip()
                            # 1. Kiểm tra log Camera
                            matched_record = next(
                                (r for r in s_records if r.subject_name and sub_name in r.subject_name), None)

                            if matched_record:
                                if matched_record.status == "Đi trễ": late_periods.append(sub_name)
                            elif is_full_day_leave or sub_name in leave_subjects:
                                # 2. Kiểm tra Đơn xin phép
                                excused_periods.append(sub_name)
                            else:
                                # 3. Đã qua giờ học mà không có mặt, không có đơn -> VẮNG MẶT
                                try:
                                    e_time_str = sub.get("timeFrame", "").split("-")[1].strip()
                                    eh, em = map(int, e_time_str.split(":"))
                                    if current_time_val > time(eh, em, 0): absent_periods.append(sub_name)
                                except:
                                    pass

                        if len(s_records) > 0: present_count += 1

                        # ---> THUẬT TOÁN QUY ĐỔI NGHỈ BUỔI MÀ BẠN YÊU CẦU <---
                        if len(absent_periods) == total_periods_today:
                            subj_violations.append({"name": s.full_name, "id": s.student_code, "type": "Nghỉ học",
                                                    "detail": "Nghỉ không phép toàn bộ các tiết (Tính là Nghỉ buổi)"})
                        elif len(excused_periods) == total_periods_today:
                            subj_violations.append({"name": s.full_name, "id": s.student_code, "type": "Có phép",
                                                    "detail": "Có đơn xin nghỉ toàn bộ các tiết (Tính là Nghỉ buổi có phép)"})
                        else:
                            # Đổ các vi phạm nhỏ lẻ ra màn hình
                            for p in absent_periods: subj_violations.append(
                                {"name": s.full_name, "id": s.student_code, "type": "Vắng mặt",
                                 "detail": f"Vắng tiết {p} (Không phép)"})
                            for p in late_periods: subj_violations.append(
                                {"name": s.full_name, "id": s.student_code, "type": "Đi trễ",
                                 "detail": f"Vào trễ tiết {p}"})
                            for p in excused_periods: subj_violations.append(
                                {"name": s.full_name, "id": s.student_code, "type": "Có phép",
                                 "detail": f"Nghỉ phép môn {p}"})

                # =======================================================
                # LUỒNG LOGIC 2: ĐIỂM DANH THEO QUY ĐỊNH CHUNG
                # =======================================================
                else:
                    if len(s_records) > 0:
                        present_count += 1
                        for r in s_records:
                            if r.status in ["Đi trễ", "Về sớm"]:
                                subj_violations.append({"name": s.full_name, "id": s.student_code, "type": r.status,
                                                        "detail": f"{r.status} lúc {r.time_in.strftime('%H:%M')}"})
                    elif is_full_day_leave:
                        subj_violations.append({"name": s.full_name, "id": s.student_code, "type": "Có phép",
                                                "detail": "Đã có Đơn xin nghỉ nguyên buổi."})
                    else:
                        # Tạm ước lượng giờ vào lớp là 8h sáng, qua 8h mà chưa quét -> Vắng mặt
                        if current_time_val > time(8, 0, 0):
                            subj_violations.append({"name": s.full_name, "id": s.student_code, "type": "Nghỉ học",
                                                    "detail": "Chưa quét Camera điểm danh (Không phép)"})

            subject_mode_list.append({
                "className": c.class_name, "teacher": teacher_name,
                "status": "perfect" if not subj_violations else "violation",
                "total": total_students, "present": present_count, "violations": subj_violations
            })

        return {"status": "success", "subject_mode": subject_mode_list, "session_mode": subject_mode_list}
    except Exception as e:
        return {"status": "error", "message": f"Lỗi lấy báo cáo: {str(e)}"}


# =====================================================================
# 5. API CẤU HÌNH GIỜ ĐIỂM DANH TỪ CAMERA
# =====================================================================
class AttendanceConfigUpdate(BaseModel):
    morning_time: str
    afternoon_time: str


@app.get("/api/projects/{project_id}/attendance-config")
def get_attendance_config(project_id: int, db: Session = Depends(get_db)):
    from database import Project
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project: return {"status": "error", "message": "Không tìm thấy dự án"}
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
    if not project: return {"status": "error", "message": "Không tìm thấy dự án"}
    try:
        project.morning_time = config.morning_time
        project.afternoon_time = config.afternoon_time
        db.commit()
        return {"status": "success", "message": "Đã lưu cấu hình giờ điểm danh thành công!"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": str(e)}


from typing import Optional, List
from pydantic import BaseModel
from datetime import datetime, date, time, timedelta


# =====================================================================
# MODEL DỮ LIỆU ĐƠN XIN NGHỈ PHÉP
# =====================================================================
class LeavePeriod(BaseModel):
    date: str
    subject: Optional[str] = None
    period: Optional[str] = None


class LeavePayload(BaseModel):
    leave_mode: str
    reason: str
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    periods: List[LeavePeriod] = []
    is_approved: bool = False




# =====================================================================
# API QUẢN LÝ ĐƠN XIN NGHỈ PHÉP CHỜ DUYỆT (HỌC SINH & GIÁO VIÊN)
# =====================================================================





# 1. API: Học sinh Gửi đơn xin nghỉ (Mặc định là chưa duyệt)
@app.post("/api/students/{student_id}/leave")
def create_leave_request(student_id: int, payload: LeavePayload, db: Session = Depends(get_db)):
    from database import Student, LeaveRequest
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student: return {"status": "error", "message": "Không tìm thấy học sinh!"}

    try:
        if payload.leave_mode == 'Theo ngày':
            start_dt = datetime.strptime(payload.start_date,
                                         "%d/%m/%Y").date() if payload.start_date else datetime.now().date()
            end_dt = datetime.strptime(payload.end_date, "%d/%m/%Y").date() if payload.end_date else start_dt
            leave = LeaveRequest(student_id=student.id, leave_mode="Nguyên ngày", start_date=start_dt, end_date=end_dt,
                                 reason=payload.reason, is_approved=payload.is_approved)
            db.add(leave)
        else:
            for p in payload.periods:
                p_date = datetime.strptime(p.date, "%d/%m/%Y").date()
                leave = LeaveRequest(student_id=student.id, leave_mode="Theo tiết", start_date=p_date, end_date=p_date,
                                     subject_name=p.subject, reason=payload.reason, is_approved=payload.is_approved)
                db.add(leave)
        db.commit()
        return {"status": "success", "message": "Đã gửi đơn xin nghỉ phép thành công!"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "message": str(e)}


# 2. API: Lấy danh sách Đơn xin nghỉ chưa duyệt của 1 lớp
@app.get("/api/classes/{class_id}/leaves")
def get_class_leaves(class_id: int, db: Session = Depends(get_db)):
    from database import LeaveRequest, Student
    students = db.query(Student).filter(Student.class_id == class_id).all()
    student_ids = [s.id for s in students]

    # Kéo các đơn có is_approved = False
    leaves = db.query(LeaveRequest).filter(LeaveRequest.student_id.in_(student_ids),
                                           LeaveRequest.is_approved == False).all()

    res = []
    for l in leaves:
        st = next((s for s in students if s.id == l.student_id), None)
        res.append({
            "id": l.id,
            "student_name": st.full_name if st else "Học sinh",
            "student_code": st.student_code if st else "",
            "leave_mode": l.leave_mode,
            "start_date": l.start_date.strftime("%d/%m/%Y") if l.start_date else "",
            "end_date": l.end_date.strftime("%d/%m/%Y") if l.end_date else "",
            "subject_name": l.subject_name or "",
            "reason": l.reason or "Không có lý do"
        })
    return {"status": "success", "data": res}


class LeaveAction(BaseModel):
    action: str  # "approve" hoặc "reject"


# 3. API: Phê duyệt hoặc Từ chối đơn
@app.put("/api/leaves/{leave_id}")
def handle_leave_request(leave_id: int, payload: LeaveAction, db: Session = Depends(get_db)):
    from database import LeaveRequest
    leave = db.query(LeaveRequest).filter(LeaveRequest.id == leave_id).first()
    if not leave: return {"status": "error", "message": "Không tìm thấy đơn"}

    if payload.action == "approve":
        leave.is_approved = True
    else:
        db.delete(leave)  # Từ chối thì xóa luôn đơn
    db.commit()
    return {"status": "success"}

# =====================================================================
# KHỞI ĐỘNG SERVER KHI CHẠY FILE .EXE
# =====================================================================
if __name__ == "__main__":
    import uvicorn
    import multiprocessing
    # Dòng này giúp đóng gói exe đa luồng không bị lỗi
    multiprocessing.freeze_support()
    uvicorn.run(app, host="127.0.0.1", port=8000)

