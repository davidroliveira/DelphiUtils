{
This software is distributed under the BSD license.

Copyright (c) 2011, Tomasz Maszkowski
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
- Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
- The name of Tomasz Maszkowski may not be used to endorse or promote
  products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

History:

}
unit TestMainForm;

interface

implementation
uses
  Classes,
  Forms,
  ActnList,
  TestFramework,
  FutureWindows,
  TestCaseBase,
  uMainForm,
  uStudentEditDialog,
  TestStudentEditDialog,
  SysUtils,
  uModel,
  Windows,
  Messages;

type
  TMainFormTestCase = class(TTestCaseBase)
  strict private
    FMainForm: TMainForm;
    procedure ExecuteMainFormAction(AAction: TAction);
    procedure AddStudent(const AName, AEmail: string; ADateOfBirth: TDate);
    procedure AddStudents(ACount: Cardinal);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestAddNewStudent;
    procedure TestAddManyStudents;
    procedure TestDeleteStudents;
    procedure TestValidation;
  end;

{ TMainFormTestCase }

procedure TMainFormTestCase.AddStudent(const AName, AEmail: string;
  ADateOfBirth: TDate);
begin
  TFutureWindows.Expect(TStudentEditDialog.ClassName, 1)
    .ExecProc(
      procedure (const AWindow: IWindow)
      var
        form: TStudentEditDialog;
      begin
        form := AWindow.AsControl as TStudentEditDialog;
        form.edName.Text := AName;
        form.edEmail.Text := AEmail;
        form.dtpDateOfBirth.Date := ADateOfBirth;

        // let us see the changes
        TTestCaseBase.ProcessMessages(0);

        form.OKBtn.Click;
      end
    );

  ExecuteMainFormAction(FMainForm.acNewStudent);
end;

procedure TMainFormTestCase.AddStudents(ACount: Cardinal);
var
  i: Integer;
begin
  for i := 1 to ACount do
  begin
    AddStudent(
      'Student ' + Char(65 + i),
      'email' + IntToStr(i) + '@test.com',
      EncodeDate(1991, 1, i)
    );
  end;
end;

procedure TMainFormTestCase.ExecuteMainFormAction(AAction: TAction);
begin
  ProcessMessages();
  AAction.Update;
  Check(AAction.Enabled, AAction.Name + ' disabled');
  AAction.Execute;
end;

type
  TFormHack = class(TForm);
procedure TMainFormTestCase.Setup;
begin
  inherited;
  FMainForm := TMainForm.Create(Application);
  FMainForm.Show;
  FMainForm.BringToFront;
  // need to investigate why actions are not updated automatically
  TFormHack(FMainForm).UpdateActions;
end;

procedure TMainFormTestCase.TearDown;
begin
  FMainForm.Free;
  FMainForm := nil;
  inherited;
end;

procedure TMainFormTestCase.TestAddManyStudents;
const
  NUM_STUDENTS = 10;
begin
  CheckEquals(0, FMainForm.CurrentCourse.StudentsCount);

  AddStudents(NUM_STUDENTS);

  CheckEquals(NUM_STUDENTS, FMainForm.CurrentCourse.StudentsCount);
end;

procedure TMainFormTestCase.TestAddNewStudent;
const
  NAME  = 'John Doe';
  EMAIL = 'john.doe@example.com';
var
  dateOfBirth: TDate;
begin
  CheckFalse(FMainForm.acEditStudent.Enabled);
  CheckFalse(FMainForm.acDeleteStudent.Enabled);

  dateOfBirth := EncodeDate(1980, 1, 1);

  CheckEquals(0, FMainForm.CurrentCourse.StudentsCount);

  AddStudent(NAME, EMAIL, dateOfBirth);

  CheckEquals(1, FMainForm.CurrentCourse.StudentsCount);

  ProcessMessages(0.5);
end;

procedure TMainFormTestCase.TestDeleteStudents;
const
  NUM_STUDENTS = 3;
var
  delCount: Integer;
  student: IStudent;
begin
  AddStudents(NUM_STUDENTS);
  CheckEquals(NUM_STUDENTS, FMainForm.CurrentCourse.StudentsCount);


  delCount := 0;
  while FMainForm.CurrentCourse.StudentsCount > 0 do
  begin
    student := FMainForm.CurrentCourse.Students[0];

    FMainForm.CurrentStudent := student;
    Check(student = FMainForm.CurrentStudent);

    // close future confirmation dialog by hitting [Enter]
    TFutureWindows.ExpectChild(FMainForm.Handle, MESSAGE_BOX_WINDOW_CLASS, 1)
      .ExecSendKey(VK_RETURN);

    ExecuteMainFormAction(FMainForm.acDeleteStudent);

    Inc(delCount);
  end;

  CheckEquals(NUM_STUDENTS, delCount);
end;

procedure TMainFormTestCase.TestValidation;
var
  studentEditForm: TStudentEditDialog;
  exceptionErrorDlg: IFutureWindow;
begin
  studentEditForm := nil;

  // wait for exception dialog
  exceptionErrorDlg := TFutureWindows.Expect(MESSAGE_BOX_WINDOW_CLASS)
    .ExecProc(
      procedure (const AWindow: IWindow)
      var
        errorMsg: string;
      begin
        ProcessMessages(0.2);

        errorMsg := AWindow.Text;

        // first close the error dialog
        AWindow.SendMessage(WM_CLOSE, 0, 0);

        CheckNotNull(studentEditForm, 'studentEditForm');

        // close the student editor
        studentEditForm.CancelBtn.Click;
      end
    );

  TFutureWindows.Expect(TStudentEditDialog.ClassName, 1)
    .ExecProc(
      procedure (const AWindow: IWindow)
      begin
        studentEditForm := AWindow.AsControl as TStudentEditDialog;
        studentEditForm.edName.Text := '';

        // let us see the changes
        TTestCaseBase.ProcessMessages(0);

        // this should raise a validation exception
        studentEditForm.OKBtn.Click;
      end
    );

  ExecuteMainFormAction(FMainForm.acNewStudent);

  Check(exceptionErrorDlg.WindowFound, 'Exception dialog was not shown');
end;

initialization
  RegisterTest(TMainFormTestCase.Suite);
end.
