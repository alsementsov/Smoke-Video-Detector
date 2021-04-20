function [Table,Pointer]  = Label_map(Label,Count,go)
[a,b]=size(Label);

Table=zeros(50,1500);
Pointer=uint16(zeros(1,50));

if (go==1)
    for i=1:a
        for j=1:b
            if Label(i,j)>0
                La=j+((i-1)*b);
                Pointer(1,Label(i,j))=Pointer(1,Label(i,j))+1;
                Table(Label(i,j),Pointer(1,Label(i,j)))=La;
            end
        end
    end
end